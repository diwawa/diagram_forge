defmodule DiagramForge.AI.ClientTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Mox

  alias DiagramForge.AI.Client

  setup :verify_on_exit!

  setup do
    # Stub the usage tracker to do nothing in these tests
    stub(DiagramForge.MockUsageTracker, :track_usage, fn _model, _usage, _opts -> :ok end)

    bypass = Bypass.open()
    %{bypass: bypass, base_url: "http://localhost:#{bypass.port}"}
  end

  describe "chat!/2" do
    test "successfully returns content from OpenAI API", %{bypass: bypass, base_url: base_url} do
      messages = [
        %{"role" => "system", "content" => "You are a helpful assistant."},
        %{"role" => "user", "content" => "Hello!"}
      ]

      Bypass.expect_once(bypass, "POST", "/chat/completions", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_body = Jason.decode!(body)

        assert request_body["model"] == "gpt-4"
        assert request_body["messages"] == messages
        assert request_body["response_format"] == %{"type" => "json_object"}
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test_api_key"]

        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" => "{\"response\": \"Hello! How can I help you?\"}"
              }
            }
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end)

      result = Client.chat!(messages, base_url: base_url, max_attempts: 1)

      assert result == "{\"response\": \"Hello! How can I help you?\"}"
    end

    test "retries on 503 and succeeds on second attempt", %{bypass: bypass, base_url: base_url} do
      messages = [%{"role" => "user", "content" => "Test"}]

      # Use a counter to track requests
      agent = start_supervised!({Agent, fn -> 0 end})

      # First request returns 503, second request succeeds
      Bypass.stub(bypass, "POST", "/chat/completions", fn conn ->
        count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if count == 0 do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(503, Jason.encode!(%{"error" => "Service unavailable"}))
        else
          response = %{
            "choices" => [
              %{"message" => %{"content" => "{\"success\": true}"}}
            ]
          }

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response))
        end
      end)

      capture_log(fn ->
        result =
          Client.chat!(messages,
            base_url: base_url,
            max_attempts: 2,
            base_delay_ms: 10,
            max_delay_ms: 100
          )

        assert result == "{\"success\": true}"
      end)
    end

    test "retries on 429 rate limit and succeeds", %{bypass: bypass, base_url: base_url} do
      messages = [%{"role" => "user", "content" => "Test"}]

      agent = start_supervised!({Agent, fn -> 0 end})

      Bypass.stub(bypass, "POST", "/chat/completions", fn conn ->
        count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if count == 0 do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(429, Jason.encode!(%{"error" => "Rate limit exceeded"}))
        else
          response = %{
            "choices" => [
              %{"message" => %{"content" => "{\"retry_success\": true}"}}
            ]
          }

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response))
        end
      end)

      capture_log(fn ->
        result =
          Client.chat!(messages,
            base_url: base_url,
            max_attempts: 2,
            base_delay_ms: 10,
            max_delay_ms: 100
          )

        assert result == "{\"retry_success\": true}"
      end)
    end

    test "raises error after max retries on 503", %{bypass: bypass, base_url: base_url} do
      messages = [%{"role" => "user", "content" => "Test"}]

      Bypass.expect(bypass, "POST", "/chat/completions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(503, Jason.encode!(%{"error" => "Service unavailable"}))
      end)

      capture_log(fn ->
        assert_raise RuntimeError, ~r/OpenAI API request failed/, fn ->
          Client.chat!(messages,
            base_url: base_url,
            max_attempts: 2,
            base_delay_ms: 10,
            max_delay_ms: 100
          )
        end
      end)
    end

    test "does not retry on 401 authentication error", %{bypass: bypass, base_url: base_url} do
      messages = [%{"role" => "user", "content" => "Test"}]

      Bypass.expect_once(bypass, "POST", "/chat/completions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(401, Jason.encode!(%{"error" => "Invalid API key"}))
      end)

      capture_log(fn ->
        assert_raise RuntimeError, ~r/OpenAI API request failed/, fn ->
          Client.chat!(messages, base_url: base_url, max_attempts: 3)
        end
      end)
    end

    test "does not retry on 400 bad request", %{bypass: bypass, base_url: base_url} do
      messages = [%{"role" => "user", "content" => "Test"}]

      Bypass.expect_once(bypass, "POST", "/chat/completions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(400, Jason.encode!(%{"error" => "Invalid request"}))
      end)

      capture_log(fn ->
        assert_raise RuntimeError, ~r/OpenAI API request failed/, fn ->
          Client.chat!(messages, base_url: base_url, max_attempts: 3)
        end
      end)
    end

    test "retries on connection error", %{bypass: bypass, base_url: base_url} do
      messages = [%{"role" => "user", "content" => "Test"}]

      agent = start_supervised!({Agent, fn -> 0 end})

      # First request fails (we'll close bypass), second request succeeds
      Bypass.stub(bypass, "POST", "/chat/completions", fn conn ->
        count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if count == 0 do
          # Return a 502 Bad Gateway to simulate network issue
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(502, Jason.encode!(%{"error" => "Bad Gateway"}))
        else
          response = %{
            "choices" => [
              %{"message" => %{"content" => "{\"recovered\": true}"}}
            ]
          }

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response))
        end
      end)

      capture_log(fn ->
        result =
          Client.chat!(messages,
            base_url: base_url,
            max_attempts: 2,
            base_delay_ms: 10,
            max_delay_ms: 100
          )

        assert result == "{\"recovered\": true}"
      end)
    end

    test "sends correct headers and request body", %{bypass: bypass, base_url: base_url} do
      messages = [%{"role" => "user", "content" => "Verify request format"}]

      Bypass.expect_once(bypass, "POST", "/chat/completions", fn conn ->
        # Verify headers
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test_api_key"]
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

        # Verify body
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_body = Jason.decode!(body)

        assert request_body["model"] == "gpt-4"
        assert request_body["messages"] == messages
        assert request_body["response_format"] == %{"type" => "json_object"}

        response = %{
          "choices" => [
            %{"message" => %{"content" => "{\"verified\": true}"}}
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end)

      result = Client.chat!(messages, base_url: base_url, max_attempts: 1)

      assert result == "{\"verified\": true}"
    end

    test "uses custom model when provided", %{bypass: bypass, base_url: base_url} do
      messages = [%{"role" => "user", "content" => "Test custom model"}]

      Bypass.expect_once(bypass, "POST", "/chat/completions", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_body = Jason.decode!(body)

        assert request_body["model"] == "gpt-4-turbo"

        response = %{
          "choices" => [
            %{"message" => %{"content" => "{\"model_test\": true}"}}
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end)

      result =
        Client.chat!(messages, base_url: base_url, model: "gpt-4-turbo", max_attempts: 1)

      assert result == "{\"model_test\": true}"
    end

    test "handles 500 server error with retry", %{bypass: bypass, base_url: base_url} do
      messages = [%{"role" => "user", "content" => "Test"}]

      agent = start_supervised!({Agent, fn -> 0 end})

      Bypass.stub(bypass, "POST", "/chat/completions", fn conn ->
        count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if count == 0 do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(500, Jason.encode!(%{"error" => "Internal server error"}))
        else
          response = %{
            "choices" => [
              %{"message" => %{"content" => "{\"recovered_from_500\": true}"}}
            ]
          }

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response))
        end
      end)

      capture_log(fn ->
        result =
          Client.chat!(messages,
            base_url: base_url,
            max_attempts: 2,
            base_delay_ms: 10,
            max_delay_ms: 100
          )

        assert result == "{\"recovered_from_500\": true}"
      end)
    end
  end

  describe "rate limit header parsing" do
    test "parses and logs rate limit headers from successful response", %{
      bypass: bypass,
      base_url: base_url
    } do
      messages = [%{"role" => "user", "content" => "Test"}]

      Bypass.expect_once(bypass, "POST", "/chat/completions", fn conn ->
        response = %{
          "choices" => [
            %{"message" => %{"content" => "{\"success\": true}"}}
          ]
        }

        conn
        |> Plug.Conn.put_resp_header("x-ratelimit-limit-requests", "500")
        |> Plug.Conn.put_resp_header("x-ratelimit-remaining-requests", "450")
        |> Plug.Conn.put_resp_header("x-ratelimit-reset-requests", "60")
        |> Plug.Conn.put_resp_header("x-ratelimit-limit-tokens", "10000")
        |> Plug.Conn.put_resp_header("x-ratelimit-remaining-tokens", "9500")
        |> Plug.Conn.put_resp_header("x-ratelimit-reset-tokens", "60")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end)

      # Above 25% threshold - should not log warnings (logs at debug level which won't show in tests)
      result = Client.chat!(messages, base_url: base_url, max_attempts: 1)
      assert result == "{\"success\": true}"
    end

    test "logs warning when approaching rate limit (below 25%)", %{
      bypass: bypass,
      base_url: base_url
    } do
      messages = [%{"role" => "user", "content" => "Test"}]

      Bypass.expect_once(bypass, "POST", "/chat/completions", fn conn ->
        response = %{
          "choices" => [
            %{"message" => %{"content" => "{\"success\": true}"}}
          ]
        }

        conn
        |> Plug.Conn.put_resp_header("x-ratelimit-limit-requests", "500")
        |> Plug.Conn.put_resp_header("x-ratelimit-remaining-requests", "100")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end)

      log =
        capture_log(fn ->
          Client.chat!(messages, base_url: base_url, max_attempts: 1)
        end)

      # Should log warning (100/500 = 20% remaining)
      assert log =~ "OpenAI rate limit approaching"
      assert log =~ "100/500"
      assert log =~ "20.0%"
    end

    test "logs critical warning when rate limit critical (below 10%)", %{
      bypass: bypass,
      base_url: base_url
    } do
      messages = [%{"role" => "user", "content" => "Test"}]

      Bypass.expect_once(bypass, "POST", "/chat/completions", fn conn ->
        response = %{
          "choices" => [
            %{"message" => %{"content" => "{\"success\": true}"}}
          ]
        }

        conn
        |> Plug.Conn.put_resp_header("x-ratelimit-limit-requests", "500")
        |> Plug.Conn.put_resp_header("x-ratelimit-remaining-requests", "25")
        |> Plug.Conn.put_resp_header("x-ratelimit-reset-requests", "120")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end)

      log =
        capture_log(fn ->
          Client.chat!(messages, base_url: base_url, max_attempts: 1)
        end)

      # Should log critical warning (25/500 = 5% remaining)
      assert log =~ "OpenAI rate limit critical"
      assert log =~ "25/500"
      assert log =~ "5.0%"
      assert log =~ "120s"
    end

    test "parses rate limit headers on error responses", %{bypass: bypass, base_url: base_url} do
      messages = [%{"role" => "user", "content" => "Test"}]

      Bypass.expect_once(bypass, "POST", "/chat/completions", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-ratelimit-limit-requests", "500")
        |> Plug.Conn.put_resp_header("x-ratelimit-remaining-requests", "0")
        |> Plug.Conn.put_resp_header("x-ratelimit-reset-requests", "60")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(429, Jason.encode!(%{"error" => "Rate limit exceeded"}))
      end)

      log =
        capture_log(fn ->
          assert_raise RuntimeError, ~r/OpenAI API request failed/, fn ->
            Client.chat!(messages, base_url: base_url, max_attempts: 1)
          end
        end)

      # Should log critical warning (0/500 = 0% remaining)
      assert log =~ "OpenAI rate limit critical"
      assert log =~ "0/500"
    end

    test "handles missing rate limit headers gracefully", %{bypass: bypass, base_url: base_url} do
      messages = [%{"role" => "user", "content" => "Test"}]

      Bypass.expect_once(bypass, "POST", "/chat/completions", fn conn ->
        response = %{
          "choices" => [
            %{"message" => %{"content" => "{\"success\": true}"}}
          ]
        }

        # No rate limit headers
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end)

      # Should not crash when headers are missing
      result = Client.chat!(messages, base_url: base_url, max_attempts: 1)
      assert result == "{\"success\": true}"
    end
  end
end
