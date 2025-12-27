defmodule DiagramForgeWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug that no longer requires authentication.

  This plug has been modified to allow all users access without authentication.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Allow all requests to pass through without authentication
    conn
  end
end
