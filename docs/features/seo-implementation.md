# SEO Implementation Plan

## Overview

DiagramForge can become a search engine magnet if users create and share public diagrams. This document outlines SEO improvements to maximize organic discovery.

## Current State

- `robots.txt` - exists but empty (default Phoenix)
- `page_title` - only set on admin pages
- No meta descriptions
- No Open Graph tags
- No sitemap.xml
- No structured data (JSON-LD)
- No canonical URLs

## Implementation Plan

### Phase 1: Core SEO Infrastructure

#### 1.1 SEO Component Module

Create `lib/diagram_forge_web/components/seo.ex` with reusable SEO components:

```elixir
defmodule DiagramForgeWeb.SEO do
  use Phoenix.Component

  @default_description "Create, share, and discover technical diagrams with AI-powered generation"
  @site_name "DiagramForge"

  def meta_tags(assigns) do
    ~H"""
    <meta name="description" content={@description || @default_description} />
    <meta name="keywords" content={@keywords || "diagrams, mermaid, flowchart, sequence diagram, architecture"} />
    <link rel="canonical" href={@canonical_url} />
    """
  end

  def open_graph(assigns) do
    ~H"""
    <meta property="og:type" content={@og_type || "website"} />
    <meta property="og:title" content={@title} />
    <meta property="og:description" content={@description || @default_description} />
    <meta property="og:url" content={@url} />
    <meta property="og:site_name" content={@site_name} />
    <meta :if={@image} property="og:image" content={@image} />
    <meta property="og:image:width" content="1200" />
    <meta property="og:image:height" content="630" />
    """
  end

  def twitter_card(assigns) do
    ~H"""
    <meta name="twitter:card" content={@card_type || "summary_large_image"} />
    <meta name="twitter:title" content={@title} />
    <meta name="twitter:description" content={@description || @default_description} />
    <meta :if={@image} name="twitter:image" content={@image} />
    """
  end

  def json_ld(assigns) do
    ~H"""
    <script type="application/ld+json">
      <%= raw(Jason.encode!(@schema)) %>
    </script>
    """
  end
end
```

#### 1.2 Update Root Layout

Modify `lib/diagram_forge_web/components/layouts/root.html.heex`:

```heex
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="csrf-token" content={get_csrf_token()} />

  <%!-- SEO Meta Tags --%>
  <meta name="description" content={assigns[:meta_description] || @default_description} />
  <meta name="keywords" content={assigns[:meta_keywords] || @default_keywords} />
  <link :if={assigns[:canonical_url]} rel="canonical" href={@canonical_url} />

  <%!-- Open Graph --%>
  <meta property="og:type" content={assigns[:og_type] || "website"} />
  <meta property="og:title" content={assigns[:page_title] || "DiagramForge"} />
  <meta property="og:description" content={assigns[:meta_description] || @default_description} />
  <meta property="og:url" content={assigns[:canonical_url] || @current_url} />
  <meta property="og:site_name" content="DiagramForge" />
  <meta :if={assigns[:og_image]} property="og:image" content={@og_image} />

  <%!-- Twitter Card --%>
  <meta name="twitter:card" content={assigns[:twitter_card] || "summary_large_image"} />
  <meta name="twitter:title" content={assigns[:page_title] || "DiagramForge"} />
  <meta name="twitter:description" content={assigns[:meta_description] || @default_description} />
  <meta :if={assigns[:og_image]} name="twitter:image" content={@og_image} />

  <%!-- Structured Data --%>
  <script :if={assigns[:json_ld]} type="application/ld+json">
    <%= raw(Jason.encode!(assigns[:json_ld])) %>
  </script>

  <link rel="icon" type="image/png" href={~p"/images/favicon.png"} />
  <.live_title default="DiagramForge" suffix=" | DiagramForge">
    {assigns[:page_title]}
  </.live_title>
  <!-- ... rest of head -->
</head>
```

### Phase 2: Dynamic Sitemap

#### 2.1 Sitemap Controller

Create `lib/diagram_forge_web/controllers/sitemap_controller.ex`:

```elixir
defmodule DiagramForgeWeb.SitemapController do
  use DiagramForgeWeb, :controller

  alias DiagramForge.Diagrams

  def index(conn, _params) do
    diagrams = Diagrams.list_public_approved_diagrams()

    conn
    |> put_resp_content_type("application/xml")
    |> render(:index, diagrams: diagrams)
  end
end
```

#### 2.2 Sitemap XML Template

Create `lib/diagram_forge_web/controllers/sitemap_xml.ex`:

```elixir
defmodule DiagramForgeWeb.SitemapXML do
  use DiagramForgeWeb, :html

  def index(assigns) do
    ~H"""
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url>
        <loc><%= url(~p"/") %></loc>
        <changefreq>daily</changefreq>
        <priority>1.0</priority>
      </url>
      <url>
        <loc><%= url(~p"/terms") %></loc>
        <changefreq>monthly</changefreq>
        <priority>0.3</priority>
      </url>
      <url>
        <loc><%= url(~p"/privacy") %></loc>
        <changefreq>monthly</changefreq>
        <priority>0.3</priority>
      </url>
      <%= for diagram <- @diagrams do %>
      <url>
        <loc><%= url(~p"/d/#{diagram.id}") %></loc>
        <lastmod><%= format_date(diagram.updated_at) %></lastmod>
        <changefreq>weekly</changefreq>
        <priority>0.8</priority>
      </url>
      <% end %>
    </urlset>
    """
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d")
  end
end
```

#### 2.3 Route Configuration

Add to router:

```elixir
scope "/", DiagramForgeWeb do
  pipe_through :browser

  get "/sitemap.xml", SitemapController, :index
end
```

### Phase 3: Robots.txt Enhancement

Update `priv/static/robots.txt`:

```
User-agent: *
Allow: /
Allow: /d/
Allow: /terms
Allow: /privacy

Disallow: /admin/
Disallow: /auth/
Disallow: /dev/

Sitemap: https://diagramforge.com/sitemap.xml
```

### Phase 4: Page-Specific SEO

#### 4.1 Homepage SEO

In `DiagramStudioLive.mount/3`:

```elixir
socket =
  socket
  |> assign(:page_title, "AI-Powered Diagram Generator")
  |> assign(:meta_description, "Create beautiful Mermaid diagrams with AI. Generate flowcharts, sequence diagrams, and architecture diagrams from natural language prompts.")
  |> assign(:canonical_url, url(~p"/"))
  |> assign(:json_ld, homepage_schema())

defp homepage_schema do
  %{
    "@context" => "https://schema.org",
    "@type" => "WebApplication",
    "name" => "DiagramForge",
    "description" => "AI-powered diagram generation tool",
    "applicationCategory" => "DesignApplication",
    "operatingSystem" => "Web",
    "offers" => %{
      "@type" => "Offer",
      "price" => "0",
      "priceCurrency" => "USD"
    }
  }
end
```

#### 4.2 Individual Diagram SEO

When viewing a specific diagram in `handle_params/3`:

```elixir
def handle_params(%{"id" => id}, _url, socket) do
  diagram = Diagrams.get_diagram!(id)

  socket =
    socket
    |> assign(:selected_diagram, diagram)
    |> assign(:page_title, diagram.title || "Untitled Diagram")
    |> assign(:meta_description, truncate_description(diagram.summary))
    |> assign(:canonical_url, url(~p"/d/#{diagram.id}"))
    |> assign(:og_type, "article")
    |> assign(:json_ld, diagram_schema(diagram))

  {:noreply, socket}
end

defp truncate_description(nil), do: nil
defp truncate_description(text) do
  if String.length(text) > 160 do
    String.slice(text, 0, 157) <> "..."
  else
    text
  end
end

defp diagram_schema(diagram) do
  %{
    "@context" => "https://schema.org",
    "@type" => "CreativeWork",
    "name" => diagram.title,
    "description" => diagram.summary,
    "dateCreated" => DateTime.to_iso8601(diagram.inserted_at),
    "dateModified" => DateTime.to_iso8601(diagram.updated_at),
    "creator" => %{
      "@type" => "Organization",
      "name" => "DiagramForge"
    },
    "keywords" => Enum.join(diagram.tags, ", ")
  }
end
```

### Phase 5: OG Image Generation (Future)

For maximum social sharing impact, generate diagram preview images:

#### 5.1 Server-Side Rendering Options

1. **Puppeteer/Playwright** - Headless browser to render Mermaid
2. **mermaid-cli** - Official CLI tool for PNG/SVG generation
3. **External service** - Use a service like Cloudinary or imgix

#### 5.2 Implementation Approach

```elixir
# Future: Generate and cache OG images
defmodule DiagramForge.OGImageGenerator do
  @cache_dir "priv/static/og-images"

  def get_or_generate(diagram) do
    cache_path = Path.join(@cache_dir, "#{diagram.id}.png")

    if File.exists?(cache_path) do
      {:ok, "/og-images/#{diagram.id}.png"}
    else
      generate_image(diagram, cache_path)
    end
  end

  defp generate_image(diagram, output_path) do
    # Use mermaid-cli or Puppeteer
    # This is a placeholder for future implementation
  end
end
```

### Phase 6: Additional SEO Enhancements

#### 6.1 Breadcrumbs (Structured Data)

```elixir
defp breadcrumb_schema(diagram) do
  %{
    "@context" => "https://schema.org",
    "@type" => "BreadcrumbList",
    "itemListElement" => [
      %{
        "@type" => "ListItem",
        "position" => 1,
        "name" => "Home",
        "item" => url(~p"/")
      },
      %{
        "@type" => "ListItem",
        "position" => 2,
        "name" => diagram.title,
        "item" => url(~p"/d/#{diagram.id}")
      }
    ]
  }
end
```

#### 6.2 FAQ Schema (for homepage)

```elixir
defp faq_schema do
  %{
    "@context" => "https://schema.org",
    "@type" => "FAQPage",
    "mainEntity" => [
      %{
        "@type" => "Question",
        "name" => "What is DiagramForge?",
        "acceptedAnswer" => %{
          "@type" => "Answer",
          "text" => "DiagramForge is an AI-powered tool for creating technical diagrams..."
        }
      }
    ]
  }
end
```

## Implementation Order

1. **Phase 1**: Core SEO infrastructure (meta tags, OG tags in root layout)
2. **Phase 2**: Dynamic sitemap generation
3. **Phase 3**: robots.txt update
4. **Phase 4**: Page-specific SEO (homepage + diagram pages)
5. **Phase 5**: OG image generation (future enhancement)
6. **Phase 6**: Additional structured data

## Files to Create/Modify

### New Files
- `lib/diagram_forge_web/components/seo.ex` - SEO helper components
- `lib/diagram_forge_web/controllers/sitemap_controller.ex` - Sitemap controller
- `lib/diagram_forge_web/controllers/sitemap_xml.ex` - Sitemap XML template

### Modified Files
- `lib/diagram_forge_web/components/layouts/root.html.heex` - Add SEO meta tags
- `lib/diagram_forge_web/router.ex` - Add sitemap route
- `lib/diagram_forge_web/live/diagram_studio_live.ex` - Add SEO assigns
- `lib/diagram_forge/diagrams.ex` - Add `list_public_approved_diagrams/0`
- `priv/static/robots.txt` - Update with proper rules

## SEO Best Practices

1. **Title tags**: 50-60 characters, include primary keyword
2. **Meta descriptions**: 150-160 characters, compelling CTA
3. **OG images**: 1200x630px for optimal social display
4. **Canonical URLs**: Always include to prevent duplicate content
5. **Structured data**: Use Schema.org vocabulary
6. **Sitemap**: Include only public, approved content
7. **Robots.txt**: Block admin and auth routes

## Success Metrics

- Google Search Console indexing status
- Organic search traffic growth
- Social media click-through rates
- Rich snippet appearances in search results

## Notes

- Slug-based URLs were intentionally not included (slugs removed from schema)
- OG image generation deferred to future phase due to complexity
- Focus on diagram visibility for approved, public content only
