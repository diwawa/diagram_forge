defmodule DiagramForge.ErrorHandling.ErrorCategorizer do
  @moduledoc """
  Categorizes errors from OpenAI API calls to determine retry strategy.

  This module analyzes errors to determine:
  - Error category (transient, permanent, rate_limit, etc.)
  - Severity level (low, medium, high, critical)
  - Whether the error is retryable

  ## Error Categories

  - `:transient` - Temporary failures (503, timeouts, network errors) - Retryable
  - `:rate_limit` - 429 Too Many Requests - Retryable with backoff
  - `:authentication` - 401/403 - Not retryable, needs admin attention
  - `:configuration` - Invalid config (missing API keys) - Not retryable
  - `:permanent` - 4xx errors (400, 404, 422) - Not retryable
  - `:network` - Connection refused, DNS failures - Retryable

  ## Examples

      iex> categorize_error({:error, %{status: 503}})
      {:transient, :medium}

      iex> categorize_error({:error, %{status: 401}})
      {:authentication, :critical}

      iex> retryable?({:error, %{status: 503}})
      true
  """

  @type error_category ::
          :transient
          | :permanent
          | :rate_limit
          | :authentication
          | :network
          | :configuration
          | :success

  @type severity :: :low | :medium | :high | :critical

  @doc """
  Categorizes an error based on HTTP status, error type, or exception.

  Returns a tuple of {category, severity}.
  """
  @spec categorize_error(term()) :: {error_category(), severity()}
  def categorize_error(error)

  # Success cases
  def categorize_error({:ok, %{status: status}}) when status >= 200 and status < 300 do
    {:success, :low}
  end

  # Rate limiting - OpenAI returns 429 when hitting rate limits
  def categorize_error({:error, %{status: 429}}) do
    {:rate_limit, :high}
  end

  # Authentication errors - invalid API key or unauthorized
  def categorize_error({:error, %{status: 401}}) do
    {:authentication, :critical}
  end

  def categorize_error({:error, %{status: 403}}) do
    {:authentication, :critical}
  end

  # Transient errors - service unavailable, gateway errors
  def categorize_error({:error, %{status: 503}}) do
    {:transient, :medium}
  end

  def categorize_error({:error, %{status: 504}}) do
    {:transient, :medium}
  end

  def categorize_error({:error, %{status: 502}}) do
    {:transient, :medium}
  end

  # Bad request - malformed request, not retryable
  def categorize_error({:error, %{status: 400}}) do
    {:permanent, :medium}
  end

  # Not found - endpoint doesn't exist
  def categorize_error({:error, %{status: 404}}) do
    {:permanent, :low}
  end

  # Conflict - duplicate request
  def categorize_error({:error, %{status: 409}}) do
    {:permanent, :medium}
  end

  # Unprocessable entity - validation failed
  def categorize_error({:error, %{status: 422}}) do
    {:permanent, :medium}
  end

  # Other 4xx errors - client errors, not retryable
  def categorize_error({:error, %{status: status}}) when status >= 400 and status < 500 do
    {:permanent, :medium}
  end

  # Other 5xx errors - server errors, retryable
  def categorize_error({:error, %{status: status}}) when status >= 500 do
    {:transient, :high}
  end

  # Network errors - connection issues, DNS failures
  def categorize_error({:error, %Req.TransportError{}}) do
    {:network, :medium}
  end

  def categorize_error({:error, :timeout}) do
    {:network, :medium}
  end

  def categorize_error({:error, :econnrefused}) do
    {:network, :medium}
  end

  def categorize_error({:error, :nxdomain}) do
    {:network, :medium}
  end

  # Configuration errors - missing API keys, invalid config
  def categorize_error({:error, :missing_api_key}) do
    {:configuration, :critical}
  end

  # Catch-all for unknown errors
  def categorize_error(_error) do
    {:permanent, :medium}
  end

  @doc """
  Determines if an error should be retried.

  Returns true for transient errors, rate limits, and network errors.
  Returns false for authentication, configuration, and permanent errors.

  ## Examples

      iex> retryable?({:error, %{status: 503}})
      true

      iex> retryable?({:error, %{status: 401}})
      false
  """
  @spec retryable?(term()) :: boolean()
  def retryable?(error) do
    {category, _severity} = categorize_error(error)

    case category do
      :transient -> true
      :rate_limit -> true
      :network -> true
      :authentication -> false
      :configuration -> false
      :permanent -> false
      :success -> false
    end
  end
end
