defmodule DiagramForge.AI.ClientBehaviour do
  @moduledoc """
  Behaviour definition for AI client.
  This allows mocking for tests using Mox.
  """

  @type message :: %{String.t() => String.t()}
  @type options :: keyword()

  @callback chat!([message()], options()) :: String.t()
end
