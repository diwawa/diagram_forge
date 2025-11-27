defmodule DiagramForgeWeb.SitemapController do
  @moduledoc """
  Controller for generating dynamic sitemap.xml.

  Only includes public, approved diagrams in the sitemap.
  """

  use DiagramForgeWeb, :controller

  alias DiagramForge.Diagrams

  @doc """
  Renders the sitemap.xml file with all indexable pages.
  """
  def index(conn, _params) do
    diagrams = Diagrams.list_public_approved_diagrams()
    base_url = DiagramForgeWeb.Endpoint.url()

    xml = build_sitemap(base_url, diagrams)

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  defp build_sitemap(base_url, diagrams) do
    diagram_urls =
      Enum.map_join(diagrams, "", fn diagram ->
        """
        <url>
          <loc>#{base_url}/d/#{diagram.id}</loc>
          <lastmod>#{format_date(diagram.updated_at)}</lastmod>
          <changefreq>weekly</changefreq>
          <priority>0.8</priority>
        </url>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url>
        <loc>#{base_url}/</loc>
        <changefreq>daily</changefreq>
        <priority>1.0</priority>
      </url>
      <url>
        <loc>#{base_url}/terms</loc>
        <changefreq>monthly</changefreq>
        <priority>0.3</priority>
      </url>
      <url>
        <loc>#{base_url}/privacy</loc>
        <changefreq>monthly</changefreq>
        <priority>0.3</priority>
      </url>
    #{diagram_urls}</urlset>
    """
  end

  defp format_date(nil), do: ""

  defp format_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d")
  end

  defp format_date(%NaiveDateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d")
  end
end
