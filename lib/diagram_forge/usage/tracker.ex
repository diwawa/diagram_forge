defmodule DiagramForge.Usage.Tracker do
  @moduledoc """
  Default implementation of usage tracking.

  This module handles tracking token usage for AI model requests.
  Usage is recorded asynchronously via a Task to avoid blocking
  the response path.
  """

  @behaviour DiagramForge.Usage.TrackerBehaviour

  require Logger

  alias DiagramForge.Usage

  @impl true
  def track_usage(model_api_name, usage, opts) do
    # Track usage asynchronously to avoid blocking the response
    Task.start(fn ->
      do_track_usage(model_api_name, usage, opts)
    end)

    :ok
  end

  @doc """
  Synchronous version of track_usage for use in tests or when
  async behavior is not desired.
  """
  def track_usage_sync(model_api_name, usage, opts) do
    do_track_usage(model_api_name, usage, opts)
    :ok
  end

  defp do_track_usage(model_api_name, usage, opts) do
    # Look up the model by API name to get the model_id
    case Usage.get_model_by_api_name(model_api_name) do
      nil ->
        Logger.warning("Unknown model for usage tracking: #{model_api_name}")

      ai_model ->
        Usage.record_usage(%{
          model_id: ai_model.id,
          user_id: opts[:user_id],
          operation: opts[:operation] || "unknown",
          input_tokens: usage["prompt_tokens"] || 0,
          output_tokens: usage["completion_tokens"] || 0,
          total_tokens: usage["total_tokens"] || 0,
          metadata: %{
            model_api_name: model_api_name
          }
        })
    end
  end
end
