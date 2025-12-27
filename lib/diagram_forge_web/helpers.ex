defmodule DiagramForgeWeb.Helpers do
  @moduledoc """
  Helper functions for the web layer.
  """

  # Add markdown_to_html function that was referenced in DiagramStudioLive
  def markdown_to_html(markdown) when is_binary(markdown) do
    Earmark.as_html!(markdown)
  end

  def markdown_to_html(_), do: ""
end