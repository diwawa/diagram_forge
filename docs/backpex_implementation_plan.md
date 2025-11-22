# Backpex Admin Panel Implementation Plan

## Overview

This document provides a comprehensive plan for integrating the Backpex admin panel into the DiagramForge application. Backpex is a LiveView-based admin interface that will provide CRUD operations for Users, Diagrams, Concepts, and Documents, accessible only to superadmins.

## Table of Contents

1. [Dependencies & Installation](#1-dependencies--installation)
2. [File Structure](#2-file-structure)
3. [Router Configuration](#3-router-configuration)
4. [Superadmin Authorization](#4-superadmin-authorization)
5. [Backpex Resources](#5-backpex-resources)
6. [Layout & Components](#6-layout--components)
7. [Test Strategy](#7-test-strategy)
8. [Migration Considerations](#8-migration-considerations)
9. [Step-by-Step Implementation](#9-step-by-step-implementation)

---

## 1. Dependencies & Installation

### 1.1 Add Dependencies to mix.exs

Add Backpex to the `deps/0` function in `/Users/mkreyman/workspace/diagram_forge/mix.exs`:

```elixir
defp deps do
  [
    # ... existing deps ...
    {:backpex, "~> 0.8.0"}
  ]
end
```

**Note**: Check the latest stable version at [hex.pm/packages/backpex](https://hex.pm/packages/backpex).

### 1.2 Install Dependencies

```bash
mix deps.get
```

### 1.3 Frontend Dependencies

Backpex uses Alpine.js and requires Tailwind CSS (already configured in DiagramForge).

**Add Alpine.js to assets/js/app.js:**

```javascript
// After existing imports, add:
import Alpine from "alpinejs"
window.Alpine = Alpine
Alpine.start()
```

**Install Alpine.js package:**

```bash
cd assets && npm install alpinejs --save
```

### 1.4 Tailwind Configuration

The project already uses Tailwind CSS v4 with the new import syntax. No changes needed to `assets/css/app.css` - Backpex styles will be automatically included through its LiveView components.

### 1.5 Verify DaisyUI

The project already includes DaisyUI (seen in `app.css`). Backpex works well with DaisyUI themes. No additional configuration needed.

---

## 2. File Structure

### 2.1 New Files to Create

```
lib/diagram_forge_web/
├── admin/
│   ├── resources/
│   │   ├── user_resource.ex              # Backpex resource for Users
│   │   ├── diagram_resource.ex           # Backpex resource for Diagrams
│   │   ├── concept_resource.ex           # Backpex resource for Concepts
│   │   └── document_resource.ex          # Backpex resource for Documents
│   └── layouts/
│       ├── admin.ex                      # Admin-specific layout module
│       └── admin.html.heex               # Admin layout template
├── plugs/
│   └── require_superadmin.ex             # New plug for superadmin-only access
└── components/
    └── admin_components.ex               # Custom admin components (optional)

test/diagram_forge_web/
├── admin/
│   ├── resources/
│   │   ├── user_resource_test.exs
│   │   ├── diagram_resource_test.exs
│   │   ├── concept_resource_test.exs
│   │   └── document_resource_test.exs
│   └── integration/
│       ├── admin_navigation_test.exs
│       └── admin_authorization_test.exs
└── plugs/
    └── require_superadmin_test.exs
```

### 2.2 Files to Modify

- `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/router.ex` - Add admin scope and routes
- `/Users/mkreyman/workspace/diagram_forge/assets/js/app.js` - Add Alpine.js import
- `/Users/mkreyman/workspace/diagram_forge/mix.exs` - Add backpex dependency
- `/Users/mkreyman/workspace/diagram_forge/config/config.exs` - Add Backpex configuration (if needed)

---

## 3. Router Configuration

### 3.1 Create Superadmin Pipeline

Add to `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/router.ex`:

```elixir
defmodule DiagramForgeWeb.Router do
  use DiagramForgeWeb, :router

  # ... existing pipelines ...

  pipeline :require_superadmin do
    plug DiagramForgeWeb.Plugs.RequireAuth
    plug DiagramForgeWeb.Plugs.RequireSuperadmin
  end

  # ... existing scopes ...

  scope "/admin", DiagramForgeWeb.Admin do
    pipe_through [:browser, :require_superadmin]

    live_session :admin,
      on_mount: [
        {DiagramForgeWeb.Plugs.Auth, :ensure_authenticated},
        {DiagramForgeWeb.Plugs.RequireSuperadmin, :ensure_superadmin}
      ] do

      # Backpex admin interface
      live "/", Backpex.LiveResource, :index,
        as: :admin_dashboard,
        resource: DiagramForgeWeb.Admin.UserResource

      # User management
      live "/users", Backpex.LiveResource, :index,
        as: :admin_users,
        resource: DiagramForgeWeb.Admin.UserResource

      live "/users/:id/edit", Backpex.LiveResource, :edit,
        as: :admin_users,
        resource: DiagramForgeWeb.Admin.UserResource

      live "/users/new", Backpex.LiveResource, :new,
        as: :admin_users,
        resource: DiagramForgeWeb.Admin.UserResource

      # Diagram management
      live "/diagrams", Backpex.LiveResource, :index,
        as: :admin_diagrams,
        resource: DiagramForgeWeb.Admin.DiagramResource

      live "/diagrams/:id/edit", Backpex.LiveResource, :edit,
        as: :admin_diagrams,
        resource: DiagramForgeWeb.Admin.DiagramResource

      live "/diagrams/new", Backpex.LiveResource, :new,
        as: :admin_diagrams,
        resource: DiagramForgeWeb.Admin.DiagramResource

      # Concept management
      live "/concepts", Backpex.LiveResource, :index,
        as: :admin_concepts,
        resource: DiagramForgeWeb.Admin.ConceptResource

      live "/concepts/:id/edit", Backpex.LiveResource, :edit,
        as: :admin_concepts,
        resource: DiagramForgeWeb.Admin.ConceptResource

      live "/concepts/new", Backpex.LiveResource, :new,
        as: :admin_concepts,
        resource: DiagramForgeWeb.Admin.ConceptResource

      # Document management
      live "/documents", Backpex.LiveResource, :index,
        as: :admin_documents,
        resource: DiagramForgeWeb.Admin.DocumentResource

      live "/documents/:id/edit", Backpex.LiveResource, :edit,
        as: :admin_documents,
        resource: DiagramForgeWeb.Admin.DocumentResource

      live "/documents/new", Backpex.LiveResource, :new,
        as: :admin_documents,
        resource: DiagramForgeWeb.Admin.DocumentResource
    end
  end
end
```

---

## 4. Superadmin Authorization

### 4.1 RequireSuperadmin Plug

Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/plugs/require_superadmin.ex`:

```elixir
defmodule DiagramForgeWeb.Plugs.RequireSuperadmin do
  @moduledoc """
  Plug that requires superadmin access.

  Must be used after RequireAuth plug to ensure current_user is loaded.
  If the user is not a superadmin, redirects to home with an error message.
  """

  import Plug.Conn
  import Phoenix.Controller
  alias DiagramForge.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    if superadmin?(conn) do
      conn
    else
      handle_unauthorized(conn)
    end
  end

  # LiveView on_mount callback
  def on_mount(:ensure_superadmin, _params, session, socket) do
    user_id = Map.get(session, "user_id")

    if user_id do
      user = Accounts.get_user(user_id)

      if Accounts.user_is_superadmin?(user) do
        {:cont, socket}
      else
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "You must be a superadmin to access this area.")
          |> Phoenix.LiveView.redirect(to: "/")

        {:halt, socket}
      end
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be logged in to access this area.")
        |> Phoenix.LiveView.redirect(to: "/")

      {:halt, socket}
    end
  end

  defp superadmin?(conn) do
    case conn.assigns[:is_superadmin] do
      true -> true
      _ -> false
    end
  end

  defp handle_unauthorized(conn) do
    conn
    |> put_flash(:error, "You must be a superadmin to access this area.")
    |> redirect(to: "/")
    |> halt()
  end
end
```

---

## 5. Backpex Resources

### 5.1 UserResource

Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/admin/resources/user_resource.ex`:

```elixir
defmodule DiagramForgeWeb.Admin.UserResource do
  @moduledoc """
  Backpex resource for managing Users in the admin panel.
  """

  use Backpex.LiveResource,
    layout: {DiagramForgeWeb.Admin.Layouts, :admin},
    schema: DiagramForge.Accounts.User,
    repo: DiagramForge.Repo,
    update_changeset: &DiagramForge.Accounts.User.changeset/2,
    create_changeset: &DiagramForge.Accounts.User.changeset/2,
    pubsub: DiagramForge.PubSub,
    topic: "users",
    event_prefix: "user_"

  @impl Backpex.LiveResource
  def singular_name, do: "User"

  @impl Backpex.LiveResource
  def plural_name, do: "Users"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{
        module: Backpex.Fields.Text,
        label: "ID",
        searchable: true,
        sortable: true,
        visible: false
      },
      email: %{
        module: Backpex.Fields.Text,
        label: "Email",
        searchable: true,
        sortable: true
      },
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true,
        sortable: true
      },
      provider: %{
        module: Backpex.Fields.Text,
        label: "Provider",
        searchable: false,
        sortable: true
      },
      provider_uid: %{
        module: Backpex.Fields.Text,
        label: "Provider UID",
        searchable: true,
        sortable: false,
        visible: false
      },
      avatar_url: %{
        module: Backpex.Fields.URL,
        label: "Avatar",
        searchable: false,
        sortable: false,
        render: fn
          %{value: nil} -> "-"
          %{value: url} -> Phoenix.HTML.Link.link("View", to: url, target: "_blank")
        end
      },
      last_sign_in_at: %{
        module: Backpex.Fields.DateTime,
        label: "Last Sign In",
        searchable: false,
        sortable: true,
        format: "{YYYY}-{0M}-{0D} {h24}:{m}:{s}"
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created",
        searchable: false,
        sortable: true,
        format: "{YYYY}-{0M}-{0D}",
        visible: false
      },
      updated_at: %{
        module: Backpex.Fields.DateTime,
        label: "Updated",
        searchable: false,
        sortable: true,
        format: "{YYYY}-{0M}-{0D}",
        visible: false
      }
    ]
  end

  @impl Backpex.LiveResource
  def can?(assigns, :index, _item), do: superadmin?(assigns)
  def can?(assigns, :new, _item), do: superadmin?(assigns)
  def can?(assigns, :show, _item), do: superadmin?(assigns)
  def can?(assigns, :edit, _item), do: superadmin?(assigns)
  def can?(assigns, :delete, _item), do: superadmin?(assigns)

  defp superadmin?(assigns) do
    Map.get(assigns, :is_superadmin, false)
  end
end
```

### 5.2 DiagramResource

Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/admin/resources/diagram_resource.ex`:

```elixir
defmodule DiagramForgeWeb.Admin.DiagramResource do
  @moduledoc """
  Backpex resource for managing Diagrams in the admin panel.
  """

  use Backpex.LiveResource,
    layout: {DiagramForgeWeb.Admin.Layouts, :admin},
    schema: DiagramForge.Diagrams.Diagram,
    repo: DiagramForge.Repo,
    update_changeset: &DiagramForge.Diagrams.Diagram.changeset/2,
    create_changeset: &DiagramForge.Diagrams.Diagram.changeset/2,
    pubsub: DiagramForge.PubSub,
    topic: "diagrams",
    event_prefix: "diagram_"

  @impl Backpex.LiveResource
  def singular_name, do: "Diagram"

  @impl Backpex.LiveResource
  def plural_name, do: "Diagrams"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{
        module: Backpex.Fields.Text,
        label: "ID",
        searchable: true,
        sortable: true,
        visible: false
      },
      title: %{
        module: Backpex.Fields.Text,
        label: "Title",
        searchable: true,
        sortable: true
      },
      slug: %{
        module: Backpex.Fields.Text,
        label: "Slug",
        searchable: true,
        sortable: true
      },
      domain: %{
        module: Backpex.Fields.Text,
        label: "Domain",
        searchable: true,
        sortable: true
      },
      tags: %{
        module: Backpex.Fields.Text,
        label: "Tags",
        searchable: false,
        sortable: false,
        render: fn
          %{value: nil} -> "-"
          %{value: []} -> "-"
          %{value: tags} -> Enum.join(tags, ", ")
        end
      },
      format: %{
        module: Backpex.Fields.Select,
        label: "Format",
        searchable: false,
        sortable: true,
        options: [
          [key: :mermaid, value: "Mermaid"],
          [key: :plantuml, value: "PlantUML"]
        ]
      },
      created_by_superadmin: %{
        module: Backpex.Fields.Boolean,
        label: "Superadmin Created",
        searchable: false,
        sortable: true
      },
      concept_id: %{
        module: Backpex.Fields.BelongsTo,
        label: "Concept",
        display_field: :name,
        searchable: false,
        sortable: false,
        options_query: fn schema, _assigns ->
          import Ecto.Query
          from(c in schema, order_by: [asc: c.name])
        end
      },
      document_id: %{
        module: Backpex.Fields.BelongsTo,
        label: "Document",
        display_field: :title,
        searchable: false,
        sortable: false,
        options_query: fn schema, _assigns ->
          import Ecto.Query
          from(d in schema, order_by: [desc: d.inserted_at])
        end
      },
      user_id: %{
        module: Backpex.Fields.BelongsTo,
        label: "User",
        display_field: :email,
        searchable: false,
        sortable: false,
        options_query: fn schema, _assigns ->
          import Ecto.Query
          from(u in schema, order_by: [asc: u.email])
        end
      },
      summary: %{
        module: Backpex.Fields.Textarea,
        label: "Summary",
        searchable: true,
        sortable: false,
        visible: false
      },
      diagram_source: %{
        module: Backpex.Fields.Textarea,
        label: "Diagram Source",
        searchable: false,
        sortable: false,
        visible: false
      },
      notes_md: %{
        module: Backpex.Fields.Textarea,
        label: "Notes (Markdown)",
        searchable: true,
        sortable: false,
        visible: false
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created",
        searchable: false,
        sortable: true,
        format: "{YYYY}-{0M}-{0D} {h24}:{m}"
      },
      updated_at: %{
        module: Backpex.Fields.DateTime,
        label: "Updated",
        searchable: false,
        sortable: true,
        format: "{YYYY}-{0M}-{0D} {h24}:{m}",
        visible: false
      }
    ]
  end

  @impl Backpex.LiveResource
  def can?(assigns, :index, _item), do: superadmin?(assigns)
  def can?(assigns, :new, _item), do: superadmin?(assigns)
  def can?(assigns, :show, _item), do: superadmin?(assigns)
  def can?(assigns, :edit, _item), do: superadmin?(assigns)
  def can?(assigns, :delete, _item), do: superadmin?(assigns)

  defp superadmin?(assigns) do
    Map.get(assigns, :is_superadmin, false)
  end
end
```

### 5.3 ConceptResource

Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/admin/resources/concept_resource.ex`:

```elixir
defmodule DiagramForgeWeb.Admin.ConceptResource do
  @moduledoc """
  Backpex resource for managing Concepts in the admin panel.
  """

  use Backpex.LiveResource,
    layout: {DiagramForgeWeb.Admin.Layouts, :admin},
    schema: DiagramForge.Diagrams.Concept,
    repo: DiagramForge.Repo,
    update_changeset: &DiagramForge.Diagrams.Concept.changeset/2,
    create_changeset: &DiagramForge.Diagrams.Concept.changeset/2,
    pubsub: DiagramForge.PubSub,
    topic: "concepts",
    event_prefix: "concept_"

  @impl Backpex.LiveResource
  def singular_name, do: "Concept"

  @impl Backpex.LiveResource
  def plural_name, do: "Concepts"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{
        module: Backpex.Fields.Text,
        label: "ID",
        searchable: true,
        sortable: true,
        visible: false
      },
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true,
        sortable: true
      },
      category: %{
        module: Backpex.Fields.Text,
        label: "Category",
        searchable: true,
        sortable: true
      },
      short_description: %{
        module: Backpex.Fields.Textarea,
        label: "Description",
        searchable: true,
        sortable: false
      },
      document_id: %{
        module: Backpex.Fields.BelongsTo,
        label: "Document",
        display_field: :title,
        searchable: false,
        sortable: false,
        options_query: fn schema, _assigns ->
          import Ecto.Query
          from(d in schema, order_by: [desc: d.inserted_at])
        end
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created",
        searchable: false,
        sortable: true,
        format: "{YYYY}-{0M}-{0D}"
      },
      updated_at: %{
        module: Backpex.Fields.DateTime,
        label: "Updated",
        searchable: false,
        sortable: true,
        format: "{YYYY}-{0M}-{0D}",
        visible: false
      }
    ]
  end

  @impl Backpex.LiveResource
  def can?(assigns, :index, _item), do: superadmin?(assigns)
  def can?(assigns, :new, _item), do: superadmin?(assigns)
  def can?(assigns, :show, _item), do: superadmin?(assigns)
  def can?(assigns, :edit, _item), do: superadmin?(assigns)
  def can?(assigns, :delete, _item), do: superadmin?(assigns)

  defp superadmin?(assigns) do
    Map.get(assigns, :is_superadmin, false)
  end
end
```

### 5.4 DocumentResource

Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/admin/resources/document_resource.ex`:

```elixir
defmodule DiagramForgeWeb.Admin.DocumentResource do
  @moduledoc """
  Backpex resource for managing Documents in the admin panel.
  """

  use Backpex.LiveResource,
    layout: {DiagramForgeWeb.Admin.Layouts, :admin},
    schema: DiagramForge.Diagrams.Document,
    repo: DiagramForge.Repo,
    update_changeset: &DiagramForge.Diagrams.Document.changeset/2,
    create_changeset: &DiagramForge.Diagrams.Document.changeset/2,
    pubsub: DiagramForge.PubSub,
    topic: "documents",
    event_prefix: "document_"

  @impl Backpex.LiveResource
  def singular_name, do: "Document"

  @impl Backpex.LiveResource
  def plural_name, do: "Documents"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{
        module: Backpex.Fields.Text,
        label: "ID",
        searchable: true,
        sortable: true,
        visible: false
      },
      title: %{
        module: Backpex.Fields.Text,
        label: "Title",
        searchable: true,
        sortable: true
      },
      source_type: %{
        module: Backpex.Fields.Select,
        label: "Source Type",
        searchable: false,
        sortable: true,
        options: [
          [key: :pdf, value: "PDF"],
          [key: :markdown, value: "Markdown"]
        ]
      },
      status: %{
        module: Backpex.Fields.Select,
        label: "Status",
        searchable: false,
        sortable: true,
        options: [
          [key: :uploaded, value: "Uploaded"],
          [key: :processing, value: "Processing"],
          [key: :ready, value: "Ready"],
          [key: :error, value: "Error"]
        ]
      },
      path: %{
        module: Backpex.Fields.Text,
        label: "File Path",
        searchable: false,
        sortable: false,
        visible: false
      },
      error_message: %{
        module: Backpex.Fields.Textarea,
        label: "Error Message",
        searchable: false,
        sortable: false,
        visible: false
      },
      raw_text: %{
        module: Backpex.Fields.Textarea,
        label: "Raw Text",
        searchable: true,
        sortable: false,
        visible: false
      },
      completed_at: %{
        module: Backpex.Fields.DateTime,
        label: "Completed At",
        searchable: false,
        sortable: true,
        format: "{YYYY}-{0M}-{0D} {h24}:{m}",
        visible: false
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created",
        searchable: false,
        sortable: true,
        format: "{YYYY}-{0M}-{0D} {h24}:{m}"
      },
      updated_at: %{
        module: Backpex.Fields.DateTime,
        label: "Updated",
        searchable: false,
        sortable: true,
        format: "{YYYY}-{0M}-{0D} {h24}:{m}",
        visible: false
      }
    ]
  end

  @impl Backpex.LiveResource
  def can?(assigns, :index, _item), do: superadmin?(assigns)
  def can?(assigns, :new, _item), do: superadmin?(assigns)
  def can?(assigns, :show, _item), do: superadmin?(assigns)
  def can?(assigns, :edit, _item), do: superadmin?(assigns)
  def can?(assigns, :delete, _item), do: superadmin?(assigns)

  defp superadmin?(assigns) do
    Map.get(assigns, :is_superadmin, false)
  end
end
```

---

## 6. Layout & Components

### 6.1 Admin Layout Module

Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/admin/layouts/admin.ex`:

```elixir
defmodule DiagramForgeWeb.Admin.Layouts do
  @moduledoc """
  Custom layouts for the admin panel.
  """

  use DiagramForgeWeb, :html

  embed_templates "admin/*"
end
```

### 6.2 Admin Layout Template

Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/admin/layouts/admin.html.heex`:

```heex
<!DOCTYPE html>
<html lang="en" class="h-full" data-theme="light">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title suffix=" · DiagramForge Admin">
      {assigns[:page_title] || "Admin"}
    </.live_title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
    </script>
  </head>
  <body class="h-full bg-base-200 antialiased">
    <div class="min-h-full">
      <%!-- Admin Navigation --%>
      <nav class="bg-primary text-primary-content shadow-md">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex h-16 items-center justify-between">
            <div class="flex items-center">
              <div class="shrink-0">
                <a href="/admin" class="text-xl font-bold">
                  DiagramForge Admin
                </a>
              </div>
              <div class="ml-10 hidden md:block">
                <div class="flex items-baseline space-x-4">
                  <.admin_nav_link navigate={~p"/admin/users"}>
                    Users
                  </.admin_nav_link>
                  <.admin_nav_link navigate={~p"/admin/diagrams"}>
                    Diagrams
                  </.admin_nav_link>
                  <.admin_nav_link navigate={~p"/admin/concepts"}>
                    Concepts
                  </.admin_nav_link>
                  <.admin_nav_link navigate={~p"/admin/documents"}>
                    Documents
                  </.admin_nav_link>
                </div>
              </div>
            </div>
            <div class="flex items-center gap-4">
              <div class="text-sm">
                {if assigns[:current_user] do}
                  {assigns.current_user.email}
                {end}
              </div>
              <a
                href="/"
                class="rounded-md px-3 py-2 text-sm font-medium hover:bg-primary-focus"
              >
                Back to App
              </a>
              <a
                href="/auth/logout"
                class="rounded-md px-3 py-2 text-sm font-medium hover:bg-primary-focus"
              >
                Logout
              </a>
            </div>
          </div>
        </div>
      </nav>

      <%!-- Flash Messages --%>
      <.flash_group flash={@flash} />

      <%!-- Main Content --%>
      <main class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        {@inner_content}
      </main>
    </div>
  </body>
</html>
```

### 6.3 Admin Navigation Component

Add to the admin layout template or create a separate component file:

```elixir
# In DiagramForgeWeb.Admin.Layouts module

def admin_nav_link(assigns) do
  ~H"""
  <.link
    navigate={@navigate}
    class="rounded-md px-3 py-2 text-sm font-medium hover:bg-primary-focus hover:text-primary-content"
  >
    {@inner_block}
  </.link>
  """
end
```

---

## 7. Test Strategy

### 7.1 Test Structure

```
test/diagram_forge_web/
├── admin/
│   ├── resources/
│   │   ├── user_resource_test.exs
│   │   ├── diagram_resource_test.exs
│   │   ├── concept_resource_test.exs
│   │   └── document_resource_test.exs
│   └── integration/
│       ├── admin_navigation_test.exs
│       └── admin_authorization_test.exs
└── plugs/
    └── require_superadmin_test.exs
```

### 7.2 RequireSuperadmin Plug Tests

Create `/Users/mkreyman/workspace/diagram_forge/test/diagram_forge_web/plugs/require_superadmin_test.exs`:

```elixir
defmodule DiagramForgeWeb.Plugs.RequireSuperadminTest do
  use DiagramForgeWeb.ConnCase, async: true

  alias DiagramForgeWeb.Plugs.RequireSuperadmin

  setup do
    # Configure superadmin for tests
    Application.put_env(:diagram_forge, :superadmin_email, "admin@example.com")

    on_exit(fn ->
      Application.delete_env(:diagram_forge, :superadmin_email)
    end)

    :ok
  end

  describe "RequireSuperadmin plug" do
    test "allows superadmin user to proceed", %{conn: conn} do
      superadmin = fixture(:user, email: "admin@example.com")

      conn =
        conn
        |> Plug.Test.init_test_session(%{user_id: superadmin.id})
        |> assign(:current_user, superadmin)
        |> assign(:is_superadmin, true)
        |> RequireSuperadmin.call(RequireSuperadmin.init([]))

      refute conn.halted
    end

    test "redirects non-superadmin authenticated user", %{conn: conn} do
      regular_user = fixture(:user, email: "regular@example.com")

      conn =
        conn
        |> Plug.Test.init_test_session(%{user_id: regular_user.id})
        |> assign(:current_user, regular_user)
        |> assign(:is_superadmin, false)
        |> RequireSuperadmin.call(RequireSuperadmin.init([]))

      assert conn.halted
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "superadmin"
    end

    test "redirects unauthenticated user", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> RequireSuperadmin.call(RequireSuperadmin.init([]))

      assert conn.halted
      assert redirected_to(conn) == "/"
    end

    test "redirects when is_superadmin is nil", %{conn: conn} do
      user = fixture(:user)

      conn =
        conn
        |> Plug.Test.init_test_session(%{user_id: user.id})
        |> assign(:current_user, user)
        |> RequireSuperadmin.call(RequireSuperadmin.init([]))

      assert conn.halted
      assert redirected_to(conn) == "/"
    end
  end

  describe "on_mount callback" do
    import Phoenix.LiveViewTest

    test "allows superadmin to mount LiveView", %{conn: conn} do
      superadmin = fixture(:user, email: "admin@example.com")

      {:ok, _view, _html} =
        conn
        |> Plug.Test.init_test_session(%{user_id: superadmin.id})
        |> assign(:current_user, superadmin)
        |> assign(:is_superadmin, true)
        |> live(~p"/admin/users")

      # Should successfully mount
    end

    test "redirects non-superadmin from LiveView", %{conn: conn} do
      regular_user = fixture(:user, email: "regular@example.com")

      assert {:error, {:redirect, %{to: "/", flash: %{"error" => message}}}} =
               conn
               |> Plug.Test.init_test_session(%{user_id: regular_user.id})
               |> assign(:current_user, regular_user)
               |> assign(:is_superadmin, false)
               |> live(~p"/admin/users")

      assert message =~ "superadmin"
    end
  end
end
```

### 7.3 UserResource Tests

Create `/Users/mkreyman/workspace/diagram_forge/test/diagram_forge_web/admin/resources/user_resource_test.exs`:

```elixir
defmodule DiagramForgeWeb.Admin.UserResourceTest do
  use DiagramForgeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    Application.put_env(:diagram_forge, :superadmin_email, "admin@example.com")
    superadmin = fixture(:user, email: "admin@example.com")

    on_exit(fn ->
      Application.delete_env(:diagram_forge, :superadmin_email)
    end)

    %{superadmin: superadmin}
  end

  describe "index" do
    test "displays users list for superadmin", %{conn: conn, superadmin: superadmin} do
      user1 = fixture(:user, email: "user1@example.com")
      user2 = fixture(:user, email: "user2@example.com")

      {:ok, view, html} =
        conn
        |> log_in_user(superadmin)
        |> live(~p"/admin/users")

      assert html =~ "Users"
      assert has_element?(view, "#user-#{user1.id}")
      assert has_element?(view, "#user-#{user2.id}")
    end

    test "allows searching users by email", %{conn: conn, superadmin: superadmin} do
      fixture(:user, email: "alice@example.com")
      fixture(:user, email: "bob@example.com")

      {:ok, view, _html} =
        conn
        |> log_in_user(superadmin)
        |> live(~p"/admin/users")

      # Perform search
      view
      |> form("#search-form", search: %{query: "alice"})
      |> render_change()

      assert has_element?(view, "#user-", "alice@example.com")
      refute has_element?(view, "#user-", "bob@example.com")
    end
  end

  describe "show" do
    test "displays user details", %{conn: conn, superadmin: superadmin} do
      user = fixture(:user, email: "test@example.com", name: "Test User")

      {:ok, _view, html} =
        conn
        |> log_in_user(superadmin)
        |> live(~p"/admin/users/#{user.id}")

      assert html =~ "Test User"
      assert html =~ "test@example.com"
    end
  end

  describe "edit" do
    test "updates user successfully", %{conn: conn, superadmin: superadmin} do
      user = fixture(:user)

      {:ok, view, _html} =
        conn
        |> log_in_user(superadmin)
        |> live(~p"/admin/users/#{user.id}/edit")

      view
      |> form("#user-form", user: %{name: "Updated Name"})
      |> render_submit()

      assert_patch(view, ~p"/admin/users")

      updated_user = DiagramForge.Accounts.get_user(user.id)
      assert updated_user.name == "Updated Name"
    end
  end

  describe "delete" do
    test "deletes user successfully", %{conn: conn, superadmin: superadmin} do
      user = fixture(:user)

      {:ok, view, _html} =
        conn
        |> log_in_user(superadmin)
        |> live(~p"/admin/users")

      view
      |> element("#delete-user-#{user.id}")
      |> render_click()

      refute DiagramForge.Accounts.get_user(user.id)
    end
  end

  # Helper function
  defp log_in_user(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{user_id: user.id})
    |> assign(:current_user, user)
    |> assign(:is_superadmin, DiagramForge.Accounts.user_is_superadmin?(user))
  end
end
```

### 7.4 Integration Tests

Create `/Users/mkreyman/workspace/diagram_forge/test/diagram_forge_web/admin/integration/admin_authorization_test.exs`:

```elixir
defmodule DiagramForgeWeb.Admin.Integration.AdminAuthorizationTest do
  use DiagramForgeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    Application.put_env(:diagram_forge, :superadmin_email, "admin@example.com")

    on_exit(fn ->
      Application.delete_env(:diagram_forge, :superadmin_email)
    end)

    :ok
  end

  describe "admin access control" do
    test "superadmin can access all admin pages", %{conn: conn} do
      superadmin = fixture(:user, email: "admin@example.com")

      admin_paths = [
        ~p"/admin/users",
        ~p"/admin/diagrams",
        ~p"/admin/concepts",
        ~p"/admin/documents"
      ]

      for path <- admin_paths do
        {:ok, _view, html} =
          conn
          |> log_in_user(superadmin)
          |> live(path)

        assert html =~ "DiagramForge Admin"
      end
    end

    test "regular user cannot access any admin page", %{conn: conn} do
      regular_user = fixture(:user, email: "regular@example.com")

      admin_paths = [
        ~p"/admin/users",
        ~p"/admin/diagrams",
        ~p"/admin/concepts",
        ~p"/admin/documents"
      ]

      for path <- admin_paths do
        assert {:error, {:redirect, %{to: "/"}}} =
                 conn
                 |> log_in_user(regular_user)
                 |> live(path)
      end
    end

    test "unauthenticated user cannot access admin pages", %{conn: conn} do
      admin_paths = [
        ~p"/admin/users",
        ~p"/admin/diagrams",
        ~p"/admin/concepts",
        ~p"/admin/documents"
      ]

      for path <- admin_paths do
        assert {:error, {:redirect, %{to: "/"}}} =
                 conn
                 |> live(path)
      end
    end
  end

  defp log_in_user(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{user_id: user.id})
    |> assign(:current_user, user)
    |> assign(:is_superadmin, DiagramForge.Accounts.user_is_superadmin?(user))
  end
end
```

### 7.5 Test Coverage Requirements

Each resource test file should cover:

1. **Index action**: List display, search, filtering, sorting
2. **Show action**: Detail view with proper data display
3. **New action**: Form rendering, validation errors
4. **Create action**: Successful creation, validation failures
5. **Edit action**: Form rendering with existing data
6. **Update action**: Successful update, validation failures
7. **Delete action**: Successful deletion, cascade behavior (if applicable)
8. **Authorization**: All actions check superadmin status

---

## 8. Migration Considerations

### 8.1 Database Indexes

All schemas already use `binary_id` primary keys. Consider adding indexes for performance:

```elixir
# Create migration: mix ecto.gen.migration add_admin_indexes

defmodule DiagramForge.Repo.Migrations.AddAdminIndexes do
  use Ecto.Migration

  def change do
    # Users
    create_if_not_exists index(:users, [:email])
    create_if_not_exists index(:users, [:provider, :provider_uid])
    create_if_not_exists index(:users, [:last_sign_in_at])

    # Diagrams
    create_if_not_exists index(:diagrams, [:slug])
    create_if_not_exists index(:diagrams, [:domain])
    create_if_not_exists index(:diagrams, [:concept_id])
    create_if_not_exists index(:diagrams, [:document_id])
    create_if_not_exists index(:diagrams, [:user_id])
    create_if_not_exists index(:diagrams, [:created_by_superadmin])

    # Concepts
    create_if_not_exists index(:concepts, [:name])
    create_if_not_exists index(:concepts, [:category])
    create_if_not_exists index(:concepts, [:document_id])

    # Documents
    create_if_not_exists index(:documents, [:status])
    create_if_not_exists index(:documents, [:source_type])
  end
end
```

### 8.2 Schema Changes

No schema changes are required. All existing schemas are compatible with Backpex.

### 8.3 Data Considerations

- Ensure existing data has valid relationships (no orphaned records)
- Consider adding a data migration to backfill any missing required fields
- Test cascading deletes if configured in schemas

---

## 9. Step-by-Step Implementation

### Phase 1: Setup (30-45 minutes)

1. **Add Dependencies**
   ```bash
   # Add backpex to mix.exs deps
   mix deps.get
   ```

2. **Install Alpine.js**
   ```bash
   cd assets
   npm install alpinejs --save
   ```

3. **Update assets/js/app.js**
   ```javascript
   import Alpine from "alpinejs"
   window.Alpine = Alpine
   Alpine.start()
   ```

4. **Verify assets build**
   ```bash
   mix assets.build
   ```

**Testing Checkpoint**: Run `mix compile` and `mix test` to ensure no regressions.

---

### Phase 2: Authorization (1 hour)

5. **Create RequireSuperadmin Plug**
   - Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/plugs/require_superadmin.ex`
   - Implement plug logic (see section 4.1)

6. **Write RequireSuperadmin Tests**
   - Create `/Users/mkreyman/workspace/diagram_forge/test/diagram_forge_web/plugs/require_superadmin_test.exs`
   - Run tests: `mix test test/diagram_forge_web/plugs/require_superadmin_test.exs`

**Testing Checkpoint**: All authorization tests should pass.

---

### Phase 3: Admin Layouts (30 minutes)

7. **Create Admin Layout Module**
   - Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/admin/layouts/admin.ex`
   - Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/admin/layouts/admin.html.heex`
   - Implement layout (see section 6)

---

### Phase 4: Resources - UserResource (1 hour)

8. **Create UserResource**
   - Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/admin/resources/user_resource.ex`
   - Implement fields and authorization (see section 5.1)

9. **Add User Routes**
   - Update router.ex with admin scope and user routes (see section 3.1)

10. **Test UserResource**
    - Create `/Users/mkreyman/workspace/diagram_forge/test/diagram_forge_web/admin/resources/user_resource_test.exs`
    - Run tests: `mix test test/diagram_forge_web/admin/resources/user_resource_test.exs`
    - Manual test: Start server, log in as superadmin, visit `/admin/users`

**Testing Checkpoint**: User CRUD operations work in browser and tests pass.

---

### Phase 5: Resources - DiagramResource (1 hour)

11. **Create DiagramResource**
    - Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/admin/resources/diagram_resource.ex`
    - Implement fields with BelongsTo associations (see section 5.2)

12. **Add Diagram Routes**
    - Add diagram routes to router.ex

13. **Test DiagramResource**
    - Create test file
    - Test CRUD operations
    - Test association rendering

**Testing Checkpoint**: Diagram CRUD works, associations display correctly.

---

### Phase 6: Resources - ConceptResource (45 minutes)

14. **Create ConceptResource**
    - Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/admin/resources/concept_resource.ex`
    - Implement fields (see section 5.3)

15. **Add Concept Routes**
    - Add concept routes to router.ex

16. **Test ConceptResource**
    - Create test file
    - Test CRUD operations

**Testing Checkpoint**: Concept CRUD works correctly.

---

### Phase 7: Resources - DocumentResource (45 minutes)

17. **Create DocumentResource**
    - Create `/Users/mkreyman/workspace/diagram_forge/lib/diagram_forge_web/admin/resources/document_resource.ex`
    - Implement fields with enum selects (see section 5.4)

18. **Add Document Routes**
    - Add document routes to router.ex

19. **Test DocumentResource**
    - Create test file
    - Test CRUD operations
    - Test status transitions

**Testing Checkpoint**: Document CRUD works, status updates correctly.

---

### Phase 8: Integration & Polish (1-2 hours)

20. **Create Integration Tests**
    - Create admin authorization integration tests (section 7.4)
    - Create admin navigation tests
    - Test superadmin-only access across all resources

21. **Run Full Test Suite**
    ```bash
    mix test
    ```

22. **Add Database Indexes**
    ```bash
    mix ecto.gen.migration add_admin_indexes
    # Add indexes from section 8.1
    mix ecto.migrate
    ```

23. **Manual Testing**
    - Log in as superadmin
    - Test each resource CRUD
    - Test search/filter/sort
    - Test associations
    - Test validation errors
    - Test as non-superadmin (should be blocked)
    - Test as unauthenticated (should be blocked)

24. **Code Quality**
    ```bash
    mix precommit
    ```

**Final Checkpoint**: All tests pass, code quality checks pass, manual testing complete.

---

### Phase 9: Documentation & Deployment (30 minutes)

25. **Update README**
    - Document admin panel access
    - Document superadmin configuration

26. **Deployment Checklist**
    - Ensure `DF_SUPERADMIN_USER` env var is set in production
    - Run migrations: `mix ecto.migrate`
    - Verify assets are compiled: `mix assets.deploy`
    - Test admin access in production

---

## Implementation Time Estimate

- **Phase 1 (Setup)**: 30-45 minutes
- **Phase 2 (Authorization)**: 1 hour
- **Phase 3 (Layouts)**: 30 minutes
- **Phase 4 (UserResource)**: 1 hour
- **Phase 5 (DiagramResource)**: 1 hour
- **Phase 6 (ConceptResource)**: 45 minutes
- **Phase 7 (DocumentResource)**: 45 minutes
- **Phase 8 (Integration)**: 1-2 hours
- **Phase 9 (Documentation)**: 30 minutes

**Total: 6-8 hours** for complete implementation with comprehensive testing.

---

## Key Patterns to Follow

### 1. Binary ID Handling

All schemas use `binary_id`. Backpex handles this automatically, but ensure:

```elixir
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
```

### 2. Authorization Pattern

Every resource must implement the `can?/3` callback:

```elixir
@impl Backpex.LiveResource
def can?(assigns, :index, _item), do: superadmin?(assigns)
def can?(assigns, :new, _item), do: superadmin?(assigns)
def can?(assigns, :show, _item), do: superadmin?(assigns)
def can?(assigns, :edit, _item), do: superadmin?(assigns)
def can?(assigns, :delete, _item), do: superadmin?(assigns)

defp superadmin?(assigns) do
  Map.get(assigns, :is_superadmin, false)
end
```

### 3. Test Pattern

All LiveView tests follow this structure:

```elixir
defmodule DiagramForgeWeb.Admin.ResourceNameTest do
  use DiagramForgeWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup do
    Application.put_env(:diagram_forge, :superadmin_email, "admin@example.com")
    superadmin = fixture(:user, email: "admin@example.com")

    on_exit(fn ->
      Application.delete_env(:diagram_forge, :superadmin_email)
    end)

    %{superadmin: superadmin}
  end

  # Tests...
end
```

### 4. Field Configuration Pattern

```elixir
field_name: %{
  module: Backpex.Fields.FieldType,
  label: "Display Label",
  searchable: true,  # Enable search
  sortable: true,     # Enable sorting
  visible: true,      # Show in index view
  render: fn          # Optional custom render
    %{value: value} -> custom_display(value)
  end
}
```

---

## Troubleshooting

### Common Issues

1. **Alpine.js not loaded**
   - Check browser console for errors
   - Verify `import Alpine from "alpinejs"` in app.js
   - Ensure `npm install alpinejs` was run

2. **Routing conflicts**
   - Ensure admin routes are in correct order
   - Verify `live_session :admin` is properly configured
   - Check pipeline order (`:browser` before `:require_superadmin`)

3. **Authorization not working**
   - Verify `is_superadmin` assign is set in Auth plug
   - Check `DF_SUPERADMIN_USER` env var matches user email
   - Ensure RequireSuperadmin plug runs after Auth plug

4. **Binary ID errors**
   - Ensure all schemas have correct primary key configuration
   - Check foreign key constraints in associations
   - Verify Ecto.UUID.generate() is used for test fixtures

5. **Association fields not working**
   - Ensure associated schema is preloaded
   - Check `display_field` matches actual schema field
   - Verify `options_query` returns correct data

---

## Additional Enhancements (Optional)

### 1. Custom Actions

Add custom actions to resources:

```elixir
@impl Backpex.LiveResource
def actions do
  [
    generate_diagram: %{
      module: Backpex.Actions.Custom,
      label: "Generate Diagram",
      handler: &handle_generate_diagram/2
    }
  ]
end
```

### 2. Filters

Add custom filters:

```elixir
@impl Backpex.LiveResource
def filters do
  [
    status: %{
      module: Backpex.Filters.Select,
      label: "Status",
      options: [uploaded: "Uploaded", ready: "Ready"]
    }
  ]
end
```

### 3. Metrics Dashboard

Create admin dashboard with metrics:

```elixir
live "/", AdminDashboardLive
```

### 4. Audit Logging

Track admin actions:

```elixir
@impl Backpex.LiveResource
def after_save(socket, item, :create) do
  AuditLog.log_create(socket.assigns.current_user, item)
  socket
end
```

---

## Conclusion

This implementation plan provides a comprehensive roadmap for integrating Backpex into DiagramForge. Follow the phases sequentially, running tests at each checkpoint to ensure stability. The modular approach allows for incremental deployment and easy troubleshooting.

For questions or issues, refer to:
- [Backpex Documentation](https://hexdocs.pm/backpex)
- [Backpex GitHub](https://github.com/naymspace/backpex)
- [Phoenix LiveView Guide](https://hexdocs.pm/phoenix_live_view)
