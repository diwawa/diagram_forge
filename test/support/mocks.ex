defmodule DiagramForge.Mocks do
  @moduledoc """
  Defines mocks for testing using Mox.

  All mocks are defined here for better organization and discoverability.
  """

  # Define mock for AI client
  Mox.defmock(DiagramForge.MockAIClient,
    for: DiagramForge.AI.ClientBehaviour
  )
end
