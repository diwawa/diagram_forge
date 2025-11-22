defmodule DiagramForgeWeb.Helpers do
  @moduledoc """
  Helper functions for templates and views.
  """

  @doc """
  Converts markdown text to HTML.

  Returns the HTML string or empty string on error.

  ## Examples

      iex> DiagramForgeWeb.Helpers.markdown_to_html("# Hello\\n- Item 1\\n- Item 2")
      "<h1>Hello</h1>\\n<ul>\\n<li>Item 1</li>\\n<li>Item 2</li>\\n</ul>\\n"

  """
  def markdown_to_html(nil), do: ""
  def markdown_to_html(""), do: ""

  def markdown_to_html(markdown) when is_binary(markdown) do
    case Earmark.as_html(markdown) do
      {:ok, html, _messages} -> html
      {:error, _html, _messages} -> markdown
    end
  end
end
