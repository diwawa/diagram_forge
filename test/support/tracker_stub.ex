defmodule DiagramForge.Usage.TrackerStub do
  @moduledoc """
  A no-op stub implementation of UsageTrackerBehaviour for tests.

  This stub does nothing, which is useful for tests that don't
  care about usage tracking but may trigger code paths that call it.
  """

  @behaviour DiagramForge.Usage.TrackerBehaviour

  @impl true
  def track_usage(_model_api_name, _usage, _opts) do
    :ok
  end
end
