defmodule DiagramForge.AI.Client do
  @moduledoc """
  Thin wrapper around the OpenAI chat completion API with retry logic.

  This module provides automatic retry with exponential backoff for transient
  failures when calling the OpenAI API.
  """

  require Logger

  @behaviour DiagramForge.AI.ClientBehaviour

  alias DiagramForge.ErrorHandling.Retry

  @cfg Application.compile_env(:diagram_forge, DiagramForge.AI)

  @doc """
  Calls the OpenAI chat completions API with the given messages.

  Automatically retries on transient failures (rate limits, network errors, 5xx).
  Returns the JSON string content from the response.

  ## Options

    * `:model` - Override the default model from config
    * `:max_attempts` - Maximum retry attempts (default: 3)
    * `:base_delay_ms` - Base retry delay in ms (default: 1000)
    * `:max_delay_ms` - Maximum retry delay in ms (default: 10000)

  ## Examples

      iex> messages = [
      ...>   %{"role" => "system", "content" => "You are a helpful assistant."},
      ...>   %{"role" => "user", "content" => "Hello!"}
      ...> ]
      iex> DiagramForge.AI.Client.chat!(messages)
      "{\"message\": \"Hello! How can I help you today?\"}"

  ## Raises

    * `RuntimeError` - If OPENAI_API_KEY is not configured
    * `RuntimeError` - If request fails after all retries

  """
  def chat!(messages, opts \\ []) do
    api_key = @cfg[:api_key] || raise "Missing OPENAI_API_KEY"
    model = opts[:model] || @cfg[:model]

    retry_opts = [
      max_attempts: opts[:max_attempts] || 3,
      base_delay_ms: opts[:base_delay_ms] || 1000,
      max_delay_ms: opts[:max_delay_ms] || 10_000,
      context: %{
        operation: "openai_chat_completion",
        model: model,
        message_count: length(messages)
      }
    ]

    case Retry.with_retry(fn -> make_request(api_key, model, messages) end, retry_opts) do
      {:ok, content} ->
        content

      {:error, reason} ->
        Logger.error("OpenAI API request failed after retries",
          reason: inspect(reason),
          model: model
        )

        raise "OpenAI API request failed: #{inspect(reason)}"
    end
  end

  # Private functions

  defp make_request(api_key, model, messages) do
    body = %{
      "model" => model,
      "messages" => messages,
      "response_format" => %{"type" => "json_object"}
    }

    case Req.post("https://api.openai.com/v1/chat/completions",
           json: body,
           headers: [
             {"authorization", "Bearer #{api_key}"},
             {"content-type", "application/json"}
           ]
         ) do
      {:ok, %{status: status} = resp} when status >= 200 and status < 300 ->
        content =
          resp.body["choices"]
          |> List.first()
          |> get_in(["message", "content"])

        {:ok, content}

      {:ok, %{status: status} = resp} ->
        {:error, %{status: status, body: resp.body}}

      {:error, _reason} = error ->
        error
    end
  end
end
