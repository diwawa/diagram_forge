defmodule DiagramForge.ErrorHandling.Retry do
  @moduledoc """
  Provides retry logic with exponential backoff for transient failures.

  This module wraps function calls with retry logic, automatically retrying
  failed operations that are considered transient or recoverable.

  ## Features

  - Exponential backoff: 1s → 2s → 4s → 8s (configurable)
  - Max delay cap to prevent excessive wait times
  - Only retries errors identified as retryable by ErrorCategorizer
  - Logs each retry attempt with context
  - Supports custom retry predicates
  - Emits telemetry events for monitoring

  ## Telemetry Events

  This module emits the following telemetry events for monitoring retry behavior:

  - `[:diagram_forge, :retry, :start]` - When retry logic begins
    - Measurements: `%{system_time: System.system_time()}`
    - Metadata: `%{max_attempts: integer(), context: map()}`

  - `[:diagram_forge, :retry, :attempt]` - On each retry attempt
    - Measurements: `%{attempt: integer(), delay_ms: integer()}`
    - Metadata: `%{error: term(), category: atom(), severity: atom(), context: map()}`

  - `[:diagram_forge, :retry, :success]` - When operation succeeds
    - Measurements: `%{attempts_used: integer(), duration: integer()}`
    - Metadata: `%{context: map()}`

  - `[:diagram_forge, :retry, :failure]` - When all retries are exhausted
    - Measurements: `%{attempts_used: integer(), duration: integer()}`
    - Metadata: `%{error: term(), context: map()}`

  ## Examples

      # Basic retry with defaults (3 attempts, 1s base delay)
      with_retry(fn ->
        Req.post(url, json: data)
      end)

      # Custom retry configuration
      with_retry(fn ->
        Req.post(url, json: data)
      end, max_attempts: 5, base_delay_ms: 2000, max_delay_ms: 30_000)

      # With custom retry predicate
      with_retry(fn ->
        make_api_call()
      end, retry_if: fn error -> custom_retryable?(error) end)
  """

  require Logger

  alias DiagramForge.ErrorHandling.ErrorCategorizer

  @default_max_attempts 3
  @default_base_delay_ms 1000
  @default_max_delay_ms 10_000

  @doc """
  Retries a function with exponential backoff.

  ## Options

  - `:max_attempts` - Maximum number of attempts (default: 3)
  - `:base_delay_ms` - Base delay in milliseconds (default: 1000)
  - `:max_delay_ms` - Maximum delay in milliseconds (default: 10000)
  - `:retry_if` - Custom predicate function to determine if error is retryable
  - `:on_retry` - Callback function called after each failed attempt
  - `:context` - Additional context for logging

  ## Examples

      with_retry(fn -> risky_operation() end)

      with_retry(fn -> api_call() end,
        max_attempts: 5,
        base_delay_ms: 2000,
        on_retry: fn attempt, error -> Logger.warning("Retry attempt") end
      )
  """
  @spec with_retry((-> term()), keyword()) :: term()
  def with_retry(func, opts \\ []) when is_function(func, 0) do
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, @default_base_delay_ms)
    max_delay_ms = Keyword.get(opts, :max_delay_ms, @default_max_delay_ms)
    retry_if = Keyword.get(opts, :retry_if, &ErrorCategorizer.retryable?/1)
    on_retry = Keyword.get(opts, :on_retry)
    context = Keyword.get(opts, :context, %{})

    # Emit telemetry start event
    start_time = System.monotonic_time()

    :telemetry.execute(
      [:diagram_forge, :retry, :start],
      %{system_time: System.system_time()},
      %{max_attempts: max_attempts, context: context}
    )

    retry_config = %{
      max_attempts: max_attempts,
      base_delay_ms: base_delay_ms,
      max_delay_ms: max_delay_ms,
      retry_if: retry_if,
      on_retry: on_retry,
      context: context,
      start_time: start_time
    }

    do_retry(func, 1, retry_config)
  end

  @doc """
  Calculates the delay for a given retry attempt using exponential backoff.

  Formula: min(base_delay * 2^(attempt - 1), max_delay)

  ## Examples

      calculate_delay(1, 1000, 10_000)
      #=> 1000

      calculate_delay(2, 1000, 10_000)
      #=> 2000

      calculate_delay(5, 1000, 10_000)
      #=> 10000 (capped at max_delay)
  """
  @spec calculate_delay(pos_integer(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def calculate_delay(attempt, base_delay, max_delay) when attempt > 0 do
    # Exponential backoff: base_delay * 2^(attempt - 1)
    delay = base_delay * :math.pow(2, attempt - 1)
    # Cap at max_delay
    min(trunc(delay), max_delay)
  end

  # Private implementation

  defp do_retry(func, attempt, config) when attempt <= config.max_attempts do
    %{context: context, start_time: start_time} = config

    case func.() do
      {:ok, _result} = success ->
        # Emit success telemetry
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:diagram_forge, :retry, :success],
          %{attempts_used: attempt, duration: duration},
          %{context: context}
        )

        success

      {:error, _reason} = error ->
        handle_error(func, error, attempt, config)

      other ->
        # If function doesn't return {:ok, _} or {:error, _}, return as-is
        # Still emit success telemetry
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:diagram_forge, :retry, :success],
          %{attempts_used: attempt, duration: duration},
          %{context: context}
        )

        other
    end
  end

  defp do_retry(_func, attempt, config) do
    %{max_attempts: max_attempts, context: context} = config

    Logger.error("Maximum retry attempts (#{max_attempts}) exceeded",
      attempt: attempt,
      context: context
    )

    {:error, :max_retries_exceeded}
  end

  defp handle_error(func, error, attempt, config) do
    %{
      max_attempts: max_attempts,
      base_delay_ms: base_delay,
      max_delay_ms: max_delay,
      retry_if: retry_if,
      on_retry: on_retry,
      context: context,
      start_time: start_time
    } = config

    should_retry = retry_if.(error)

    if should_retry and attempt < max_attempts do
      {category, severity} = ErrorCategorizer.categorize_error(error)
      delay = calculate_delay(attempt, base_delay, max_delay)

      # Emit telemetry for retry attempt
      :telemetry.execute(
        [:diagram_forge, :retry, :attempt],
        %{attempt: attempt, delay_ms: delay},
        %{error: error, category: category, severity: severity, context: context}
      )

      Logger.warning("Retry attempt #{attempt}/#{max_attempts} after #{delay}ms",
        error: inspect(error),
        category: category,
        severity: severity,
        next_delay_ms: delay,
        context: context
      )

      # Call on_retry callback if provided
      if on_retry do
        on_retry.(attempt, error)
      end

      # Wait before retrying
      Process.sleep(delay)

      # Retry
      do_retry(func, attempt + 1, config)
    else
      # Error is not retryable or max attempts reached
      duration = System.monotonic_time() - start_time

      if should_retry do
        Logger.error("Maximum retry attempts (#{max_attempts}) exceeded",
          error: inspect(error),
          context: context
        )

        # Emit failure telemetry
        :telemetry.execute(
          [:diagram_forge, :retry, :failure],
          %{attempts_used: attempt, duration: duration},
          %{error: error, context: context}
        )
      else
        {category, severity} = ErrorCategorizer.categorize_error(error)

        Logger.info("Error not retryable, failing immediately",
          error: inspect(error),
          category: category,
          severity: severity,
          context: context
        )

        # Emit failure telemetry
        :telemetry.execute(
          [:diagram_forge, :retry, :failure],
          %{attempts_used: attempt, duration: duration},
          %{error: error, context: context}
        )
      end

      error
    end
  end
end
