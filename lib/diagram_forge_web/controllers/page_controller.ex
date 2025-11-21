defmodule DiagramForgeWeb.PageController do
  use DiagramForgeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
