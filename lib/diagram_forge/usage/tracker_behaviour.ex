defmodule DiagramForge.Usage.TrackerBehaviour do
  @moduledoc """
  Behaviour definition for usage tracking.

  This allows mocking the usage tracker in tests to avoid database
  connection issues with async Task processes in the Ecto Sandbox.
  """

  @type model_api_name :: String.t()
  @type usage :: map()
  @type opts :: keyword()

  @doc """
  Tracks token usage for an AI model request.

  ## Parameters

    * `model_api_name` - The API name of the model (e.g., "gpt-4o-mini")
    * `usage` - Map containing token usage from the API response
    * `opts` - Options including `:user_id` and `:operation`

  """
  @callback track_usage(model_api_name(), usage(), opts()) :: :ok
end
