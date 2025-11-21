defmodule DiagramForge.AI.Client do
  @moduledoc """
  Thin wrapper around the OpenAI chat completion API.
  """

  @behaviour DiagramForge.AI.ClientBehaviour

  @cfg Application.compile_env(:diagram_forge, DiagramForge.AI)

  @doc """
  Calls the OpenAI chat completions API with the given messages.

  Returns the JSON string content from the response.

  ## Options

    * `:model` - Override the default model from config

  ## Examples

      iex> messages = [
      ...>   %{"role" => "system", "content" => "You are a helpful assistant."},
      ...>   %{"role" => "user", "content" => "Hello!"}
      ...> ]
      iex> DiagramForge.AI.Client.chat!(messages)
      "{\"message\": \"Hello! How can I help you today?\"}"

  """
  def chat!(messages, opts \\ []) do
    api_key = @cfg[:api_key] || raise "Missing OPENAI_API_KEY"
    model = opts[:model] || @cfg[:model]

    body = %{
      "model" => model,
      "messages" => messages,
      "response_format" => %{"type" => "json_object"}
    }

    resp =
      Req.post!("https://api.openai.com/v1/chat/completions",
        json: body,
        headers: [
          {"authorization", "Bearer #{api_key}"},
          {"content-type", "application/json"}
        ]
      )

    content =
      resp.body["choices"]
      |> List.first()
      |> get_in(["message", "content"])

    content
  end
end
