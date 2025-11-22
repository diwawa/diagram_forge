# GitHub OAuth Authentication Implementation Plan

## Overview

Implement GitHub OAuth authentication for DiagramForge, following the established pattern from outbound_call_center. Users will authenticate only via GitHub OAuth (no other providers).

## Authorization Model

### User Access Levels

1. **Superadmin** (email from `DF_SUPERADMIN_USER` env var)
   - Can manage all resources (implementation later)
   - Full system access

2. **Authenticated Users**
   - Can see their own diagrams (`user_id = current_user.id`)
   - Can see diagrams created by superadmin (`created_by_superadmin = true`)
   - Can see "public" diagrams (`user_id IS NULL`)
   - Cannot see other users' diagrams
   - Can create their own diagrams

3. **Unauthenticated (Guest) Users**
   - Can only view "public" diagrams (`user_id IS NULL` or `created_by_superadmin = true`)
   - Cannot create diagrams
   - Cannot save or manage diagrams

## Implementation Steps

### 1. Add Dependencies

Add to `mix.exs`:

```elixir
{:ueberauth, "~> 0.10"},
{:ueberauth_github, "~> 0.8"}
```

### 2. Configuration

**File: `config/config.exs`**

```elixir
# Configure Ueberauth for GitHub OAuth only
config :ueberauth, Ueberauth,
  providers: [
    github: {Ueberauth.Strategy.Github, [default_scope: "user:email"]}
  ]

config :ueberauth, Ueberauth.Strategy.Github.OAuth,
  client_id: System.get_env("GITHUB_CLIENT_ID"),
  client_secret: System.get_env("GITHUB_CLIENT_SECRET")
```

**File: `config/runtime.exs`**

Add superadmin configuration:

```elixir
config :diagram_forge,
  superadmin_email: System.get_env("DF_SUPERADMIN_USER")
```

### 3. Database Schema

**Migration: `create_users.exs`**

```elixir
create table(:users, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :email, :string, null: false
  add :name, :string
  add :provider, :string, default: "github", null: false
  add :provider_uid, :string, null: false
  add :provider_token, :text
  add :avatar_url, :string
  add :last_sign_in_at, :utc_datetime

  timestamps()
end

create unique_index(:users, [:email])
create unique_index(:users, [:provider, :provider_uid])
```

**Migration: `add_user_id_to_diagrams.exs`**

```elixir
alter table(:diagrams) do
  add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
  add :created_by_superadmin, :boolean, default: false, null: false
end

create index(:diagrams, [:user_id])
create index(:diagrams, [:created_by_superadmin])
```

### 4. User Schema

**File: `lib/diagram_forge/accounts/user.ex`**

```elixir
defmodule DiagramForge.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :name, :string
    field :provider, :string, default: "github"
    field :provider_uid, :string
    field :provider_token, :binary
    field :avatar_url, :string
    field :last_sign_in_at, :utc_datetime

    has_many :diagrams, DiagramForge.Diagrams.Diagram

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :provider, :provider_uid, :provider_token, :avatar_url])
    |> validate_required([:email, :provider, :provider_uid])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> unique_constraint(:email)
    |> unique_constraint([:provider, :provider_uid])
  end

  def sign_in_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:last_sign_in_at])
    |> put_change(:last_sign_in_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end
end
```

### 5. Accounts Context

**File: `lib/diagram_forge/accounts.ex`**

```elixir
defmodule DiagramForge.Accounts do
  import Ecto.Query
  alias DiagramForge.Repo
  alias DiagramForge.Accounts.User

  def upsert_user_from_oauth(attrs) do
    case get_user_by_provider(attrs[:provider], attrs[:provider_uid]) do
      nil ->
        case get_user_by_email(attrs[:email]) do
          nil ->
            %User{}
            |> User.changeset(attrs)
            |> Repo.insert()

          user ->
            user
            |> User.changeset(attrs)
            |> User.sign_in_changeset()
            |> Repo.update()
        end

      user ->
        user
        |> User.changeset(attrs)
        |> User.sign_in_changeset()
        |> Repo.update()
    end
  end

  def get_user(id) do
    Repo.get(User, id)
  end

  def get_user_by_provider(provider, provider_uid) do
    User
    |> where([u], u.provider == ^provider and u.provider_uid == ^provider_uid)
    |> Repo.one()
  end

  def get_user_by_email(email) do
    User
    |> where([u], u.email == ^email)
    |> Repo.one()
  end

  def user_is_superadmin?(%User{email: email}) do
    superadmin_email = Application.get_env(:diagram_forge, :superadmin_email)
    superadmin_email && email == superadmin_email
  end

  def user_is_superadmin?(nil), do: false
end
```

### 6. Auth Controller

**File: `lib/diagram_forge_web/controllers/auth_controller.ex`**

```elixir
defmodule DiagramForgeWeb.AuthController do
  use DiagramForgeWeb, :controller

  alias DiagramForge.Accounts

  plug Ueberauth

  def request(conn, _params) do
    conn  # Let Ueberauth handle OAuth request
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_attrs = %{
      email: auth.info.email,
      name: auth.info.name,
      provider: to_string(auth.provider),
      provider_uid: to_string(auth.uid),
      provider_token: auth.credentials.token,
      avatar_url: auth.info.image
    }

    case Accounts.upsert_user_from_oauth(user_attrs) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Successfully signed in!")
        |> put_session(:user_id, user.id)
        |> delete_session(:return_to)
        |> configure_session(renew: true)
        |> redirect(to: get_redirect_path(conn))

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Failed to sign in. Please try again.")
        |> redirect(to: "/")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Authentication failed. Please try again.")
    |> redirect(to: "/")
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: "/")
  end

  defp get_redirect_path(conn) do
    get_session(conn, :return_to) || "/"
  end
end
```

### 7. Authentication Plugs

**File: `lib/diagram_forge_web/plugs/auth.ex`**

```elixir
defmodule DiagramForgeWeb.Plugs.Auth do
  import Plug.Conn
  alias DiagramForge.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    cond do
      conn.assigns[:current_user] ->
        conn

      user_id ->
        case Accounts.get_user(user_id) do
          nil ->
            conn
            |> assign(:current_user, nil)
            |> configure_session(drop: true)

          user ->
            conn
            |> assign(:current_user, user)
            |> assign(:is_superadmin, Accounts.user_is_superadmin?(user))
        end

      true ->
        assign(conn, :current_user, nil)
    end
  end
end
```

**File: `lib/diagram_forge_web/plugs/require_auth.ex`**

```elixir
defmodule DiagramForgeWeb.Plugs.RequireAuth do
  import Plug.Conn
  import Phoenix.Controller
  alias DiagramForge.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      user_id = get_session(conn, :user_id)
      user = if user_id, do: Accounts.get_user(user_id)

      if user do
        assign(conn, :current_user, user)
      else
        handle_unauthenticated(conn)
      end
    end
  end

  defp handle_unauthenticated(conn) do
    return_to =
      if should_store_return_path?(conn.request_path) do
        conn.request_path
      end

    conn
    |> clear_session()
    |> maybe_put_return_to(return_to)
    |> put_flash(:error, "You must be logged in to access this page.")
    |> redirect(to: "/")
    |> halt()
  end

  defp maybe_put_return_to(conn, nil), do: conn
  defp maybe_put_return_to(conn, path), do: put_session(conn, :return_to, path)

  defp should_store_return_path?(path) when is_binary(path) do
    not String.starts_with?(path, "/auth/") and
      String.starts_with?(path, "/") and
      not String.starts_with?(path, "//")
  end
end
```

### 8. Routes

**File: `lib/diagram_forge_web/router.ex`**

Update the browser pipeline:

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {DiagramForgeWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug DiagramForgeWeb.Plugs.Auth  # Add this line
end

pipeline :require_auth do
  plug DiagramForgeWeb.Plugs.RequireAuth
end
```

Add auth routes:

```elixir
scope "/auth", DiagramForgeWeb do
  pipe_through :browser

  get "/github", AuthController, :request
  get "/github/callback", AuthController, :callback
  get "/logout", AuthController, :logout
end
```

### 9. LiveView Authentication Hook

**File: `lib/diagram_forge_web/live/user_live.ex`**

```elixir
defmodule DiagramForgeWeb.UserLive do
  import Phoenix.Component
  import Phoenix.LiveView

  alias DiagramForge.Accounts

  def on_mount(:default, _params, session, socket) do
    user_id = session["user_id"]

    socket =
      socket
      |> assign_new(:current_user, fn -> load_user(user_id) end)
      |> assign_new(:is_superadmin, fn ->
        case socket.assigns[:current_user] do
          nil -> false
          user -> Accounts.user_is_superadmin?(user)
        end
      end)

    {:cont, socket}
  end

  def on_mount(:require_auth, _params, session, socket) do
    case on_mount(:default, nil, session, socket) do
      {:cont, socket} ->
        if socket.assigns[:current_user] do
          {:cont, socket}
        else
          {:halt, redirect(socket, to: "/")}
        end
    end
  end

  defp load_user(nil), do: nil
  defp load_user(user_id), do: Accounts.get_user(user_id)
end
```

### 10. Update Diagram Authorization

**File: `lib/diagram_forge/diagrams.ex`**

Add filtering functions:

```elixir
@doc """
Lists diagrams visible to the given user.

- Superadmin: sees all diagrams
- Authenticated user: sees own diagrams + public diagrams + superadmin diagrams
- Guest (nil user): sees only public diagrams
"""
def list_visible_diagrams(user \\ nil) do
  cond do
    user && Accounts.user_is_superadmin?(user) ->
      list_diagrams()

    user ->
      Repo.all(
        from d in Diagram,
          where:
            d.user_id == ^user.id or
            is_nil(d.user_id) or
            d.created_by_superadmin == true,
          order_by: [desc: d.inserted_at]
      )

    true ->
      Repo.all(
        from d in Diagram,
          where: is_nil(d.user_id) or d.created_by_superadmin == true,
          order_by: [desc: d.inserted_at]
      )
  end
end

@doc """
Creates a diagram with user ownership.
"""
def create_diagram_for_user(attrs, user) do
  is_superadmin = user && Accounts.user_is_superadmin?(user)

  attrs =
    attrs
    |> Map.put(:user_id, user && user.id)
    |> Map.put(:created_by_superadmin, is_superadmin)

  %Diagram{}
  |> Diagram.changeset(attrs)
  |> Repo.insert()
end
```

### 11. Update UI Components

Add login/logout button to the header in `lib/diagram_forge_web/components/layouts/app.html.heex`:

```heex
<header class="bg-slate-950 border-b border-slate-800">
  <div class="container mx-auto px-4 py-4 flex items-center justify-between">
    <h1 class="text-2xl font-bold text-white">DiagramForge Studio</h1>
    <div class="flex items-center gap-4">
      <%= if @current_user do %>
        <span class="text-sm text-slate-400">
          <%= @current_user.email %>
        </span>
        <.link href="/auth/logout" class="text-sm text-slate-300 hover:text-white">
          Sign Out
        </.link>
      <% else %>
        <.link href="/auth/github" class="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-white rounded transition">
          Sign in with GitHub
        </.link>
      <% end %>
    </div>
  </div>
</header>
```

## Environment Variables Required

```bash
# GitHub OAuth
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret

# Superadmin
DF_SUPERADMIN_USER=your_admin_email@example.com
```

## Testing Strategy

1. **Unit Tests**
   - `Accounts.upsert_user_from_oauth/1`
   - `Accounts.user_is_superadmin?/1`
   - Diagram visibility queries

2. **Integration Tests**
   - OAuth callback flow
   - Session management
   - Logout flow

3. **LiveView Tests**
   - Unauthenticated access to DiagramStudioLive
   - Authenticated user sees own diagrams
   - Users cannot see each other's diagrams

## Migration Path

1. Install dependencies
2. Add configuration
3. Create migrations and run them
4. Create User schema and Accounts context
5. Create AuthController and plugs
6. Update routes
7. Create UserLive hook
8. Update Diagrams context with authorization
9. Update UI with login/logout
10. Test thoroughly

## Security Considerations

- GitHub OAuth tokens stored encrypted
- Session regeneration on login
- Session drop on logout
- Return path validation to prevent open redirects
- User isolation in diagram queries
- Superadmin verification through Application config
