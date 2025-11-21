defmodule DiagramForge.ErrorHandling.RetryTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias DiagramForge.ErrorHandling.Retry

  describe "calculate_delay/3" do
    test "calculates delay using exponential backoff" do
      assert Retry.calculate_delay(1, 1000, 10_000) == 1000
      assert Retry.calculate_delay(2, 1000, 10_000) == 2000
      assert Retry.calculate_delay(3, 1000, 10_000) == 4000
      assert Retry.calculate_delay(4, 1000, 10_000) == 8000
    end

    test "caps delay at max_delay" do
      assert Retry.calculate_delay(5, 1000, 10_000) == 10_000
      assert Retry.calculate_delay(10, 1000, 10_000) == 10_000
    end

    test "works with different base delays" do
      assert Retry.calculate_delay(1, 2000, 20_000) == 2000
      assert Retry.calculate_delay(2, 2000, 20_000) == 4000
      assert Retry.calculate_delay(3, 2000, 20_000) == 8000
    end
  end

  describe "with_retry/2" do
    test "returns result on first success" do
      func = fn -> {:ok, "success"} end

      assert {:ok, "success"} = Retry.with_retry(func)
    end

    test "returns error immediately if not retryable" do
      func = fn -> {:error, %{status: 401}} end

      assert {:error, %{status: 401}} = Retry.with_retry(func)
    end

    test "retries on transient errors and succeeds" do
      # First call fails with transient error, second succeeds
      agent = start_supervised!({Agent, fn -> 0 end})

      func = fn ->
        count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if count == 0 do
          {:error, %{status: 503}}
        else
          {:ok, "success"}
        end
      end

      # Should retry once and succeed
      capture_log(fn ->
        assert {:ok, "success"} =
                 Retry.with_retry(func, base_delay_ms: 10, max_delay_ms: 100)
      end)
    end

    test "returns original error after max retries exceeded" do
      func = fn -> {:error, %{status: 503}} end

      capture_log(fn ->
        assert {:error, %{status: 503}} =
                 Retry.with_retry(func, max_attempts: 2, base_delay_ms: 10, max_delay_ms: 100)
      end)
    end

    test "calls on_retry callback on each retry" do
      test_pid = self()

      func = fn -> {:error, %{status: 503}} end

      on_retry = fn attempt, _error ->
        send(test_pid, {:retry, attempt})
      end

      capture_log(fn ->
        Retry.with_retry(func,
          max_attempts: 3,
          base_delay_ms: 10,
          max_delay_ms: 100,
          on_retry: on_retry
        )
      end)

      # Should have received 2 retry callbacks (attempt 1 fails, retry on 2, retry on 3)
      assert_received {:retry, 1}
      assert_received {:retry, 2}
      refute_received {:retry, 3}
    end

    test "uses custom retry predicate" do
      func = fn -> {:error, :custom_error} end

      # Custom predicate that always says retry
      retry_if = fn _error -> true end

      capture_log(fn ->
        assert {:error, :custom_error} =
                 Retry.with_retry(func,
                   max_attempts: 2,
                   base_delay_ms: 10,
                   max_delay_ms: 100,
                   retry_if: retry_if
                 )
      end)
    end

    test "handles non-tuple return values" do
      func = fn -> "plain value" end

      assert "plain value" = Retry.with_retry(func)
    end

    test "respects configured max_attempts" do
      agent = start_supervised!({Agent, fn -> 0 end})

      func = fn ->
        Agent.update(agent, fn n -> n + 1 end)
        {:error, %{status: 503}}
      end

      capture_log(fn ->
        Retry.with_retry(func, max_attempts: 5, base_delay_ms: 10, max_delay_ms: 100)
      end)

      # Should have tried 5 times total
      assert Agent.get(agent, & &1) == 5
    end
  end
end
