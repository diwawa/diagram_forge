defmodule DiagramForge.ErrorHandling.RetryTelemetryTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias DiagramForge.ErrorHandling.Retry

  setup do
    # Attach telemetry handler
    test_pid = self()
    test_ref = make_ref()

    handler_id = "test-retry-telemetry-#{inspect(make_ref())}"

    :telemetry.attach_many(
      handler_id,
      [
        [:diagram_forge, :retry, :start],
        [:diagram_forge, :retry, :attempt],
        [:diagram_forge, :retry, :success],
        [:diagram_forge, :retry, :failure]
      ],
      fn event, measurements, metadata, _config ->
        # Only send events for this test's context
        if Map.get(metadata.context || %{}, :test_ref) == test_ref do
          send(test_pid, {:telemetry_event, event, measurements, metadata})
        end
      end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

    %{test_ref: test_ref}
  end

  describe "telemetry events" do
    test "emits start and success events on first attempt success", %{test_ref: test_ref} do
      func = fn -> {:ok, "success"} end

      result = Retry.with_retry(func, max_attempts: 3, context: %{test_ref: test_ref})

      assert result == {:ok, "success"}

      # Should receive start event
      assert_received {:telemetry_event, [:diagram_forge, :retry, :start], measurements, metadata}

      assert measurements.system_time > 0
      assert metadata.max_attempts == 3
      assert metadata.context.test_ref == test_ref

      # Should receive success event
      assert_received {:telemetry_event, [:diagram_forge, :retry, :success], measurements,
                       metadata}

      assert measurements.attempts_used == 1
      assert measurements.duration > 0
      assert metadata.context.test_ref == test_ref

      # Should NOT receive any retry attempt or failure events
      refute_received {:telemetry_event, [:diagram_forge, :retry, :attempt], _, _}
      refute_received {:telemetry_event, [:diagram_forge, :retry, :failure], _, _}
    end

    test "emits retry attempt events on transient failures", %{test_ref: test_ref} do
      agent = start_supervised!({Agent, fn -> 0 end})

      func = fn ->
        count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if count < 2 do
          {:error, %{status: 503}}
        else
          {:ok, "recovered"}
        end
      end

      capture_log(fn ->
        result =
          Retry.with_retry(func,
            max_attempts: 3,
            base_delay_ms: 10,
            max_delay_ms: 100,
            context: %{test_ref: test_ref}
          )

        assert result == {:ok, "recovered"}
      end)

      # Should receive start event
      assert_received {:telemetry_event, [:diagram_forge, :retry, :start], _, _}

      # Should receive 2 retry attempt events (failed attempts 1 and 2)
      assert_received {:telemetry_event, [:diagram_forge, :retry, :attempt], measurements1,
                       metadata1}

      assert measurements1.attempt == 1
      assert measurements1.delay_ms > 0
      assert metadata1.category == :transient
      assert metadata1.severity == :medium

      assert_received {:telemetry_event, [:diagram_forge, :retry, :attempt], measurements2,
                       metadata2}

      assert measurements2.attempt == 2
      assert metadata2.category == :transient

      # Should receive success event (attempt 3 succeeded)
      assert_received {:telemetry_event, [:diagram_forge, :retry, :success], measurements,
                       metadata}

      assert measurements.attempts_used == 3
      assert metadata.context.test_ref == test_ref

      # Should NOT receive failure event
      refute_received {:telemetry_event, [:diagram_forge, :retry, :failure], _, _}
    end

    test "emits failure event when max retries exceeded", %{test_ref: test_ref} do
      func = fn -> {:error, %{status: 503}} end

      capture_log(fn ->
        result =
          Retry.with_retry(func,
            max_attempts: 2,
            base_delay_ms: 10,
            max_delay_ms: 100,
            context: %{test_ref: test_ref}
          )

        assert result == {:error, %{status: 503}}
      end)

      # Should receive start event
      assert_received {:telemetry_event, [:diagram_forge, :retry, :start], _, _}

      # Should receive 1 retry attempt event (attempt 1 failed, retry on attempt 2)
      assert_received {:telemetry_event, [:diagram_forge, :retry, :attempt], measurements, _}
      assert measurements.attempt == 1

      # Should receive failure event (attempt 2 failed, no more retries)
      assert_received {:telemetry_event, [:diagram_forge, :retry, :failure], measurements,
                       metadata}

      assert measurements.attempts_used == 2
      assert measurements.duration > 0
      assert metadata.context.test_ref == test_ref
      assert match?({:error, %{status: 503}}, metadata.error)

      # Should NOT receive success event
      refute_received {:telemetry_event, [:diagram_forge, :retry, :success], _, _}
    end

    test "emits failure event immediately for non-retryable errors", %{test_ref: test_ref} do
      func = fn -> {:error, %{status: 401}} end

      capture_log(fn ->
        result = Retry.with_retry(func, max_attempts: 3, context: %{test_ref: test_ref})

        assert result == {:error, %{status: 401}}
      end)

      # Should receive start event
      assert_received {:telemetry_event, [:diagram_forge, :retry, :start], _, _}

      # Should receive failure event immediately
      assert_received {:telemetry_event, [:diagram_forge, :retry, :failure], measurements,
                       metadata}

      assert measurements.attempts_used == 1
      assert metadata.context.test_ref == test_ref

      # Should NOT receive any retry attempt or success events
      refute_received {:telemetry_event, [:diagram_forge, :retry, :attempt], _, _}
      refute_received {:telemetry_event, [:diagram_forge, :retry, :success], _, _}
    end

    test "includes error category and severity in retry attempt metadata", %{test_ref: test_ref} do
      agent = start_supervised!({Agent, fn -> 0 end})

      func = fn ->
        count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if count == 0 do
          {:error, %{status: 429}}
        else
          {:ok, "success"}
        end
      end

      capture_log(fn ->
        Retry.with_retry(func,
          max_attempts: 2,
          base_delay_ms: 10,
          max_delay_ms: 100,
          context: %{test_ref: test_ref}
        )
      end)

      # Should receive retry attempt event with error details
      assert_received {:telemetry_event, [:diagram_forge, :retry, :attempt], measurements,
                       metadata}

      assert measurements.attempt == 1
      assert measurements.delay_ms > 0
      assert metadata.category == :rate_limit
      assert metadata.severity == :high
      assert match?({:error, %{status: 429}}, metadata.error)
    end

    test "tracks duration correctly across multiple retries", %{test_ref: test_ref} do
      agent = start_supervised!({Agent, fn -> 0 end})

      func = fn ->
        count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if count < 2 do
          {:error, %{status: 503}}
        else
          {:ok, "recovered"}
        end
      end

      start_time = System.monotonic_time()

      capture_log(fn ->
        Retry.with_retry(func,
          max_attempts: 3,
          base_delay_ms: 10,
          max_delay_ms: 100,
          context: %{test_ref: test_ref}
        )
      end)

      # Should receive success event with duration
      assert_received {:telemetry_event, [:diagram_forge, :retry, :success], measurements, _}

      # Duration should include all retry delays (approx 10ms + 20ms = 30ms)
      # Using a range to account for test execution time
      total_time = System.monotonic_time() - start_time
      assert measurements.duration > 0
      assert measurements.duration <= total_time
    end
  end
end
