defmodule DiagramForgeWeb.Admin.AlertHistoryLive do
  @moduledoc """
  Admin page for viewing and acknowledging usage alerts.
  """

  use DiagramForgeWeb, :live_view

  alias DiagramForge.Usage

  @impl true
  def render(assigns) do
    ~H"""
    <Backpex.HTML.Layout.app_shell fluid={false}>
      <:topbar>
        <Backpex.HTML.Layout.topbar_branding title="DiagramForge Admin" />

        <div class="flex items-center gap-2">
          <.link navigate={~p"/admin/dashboard"} class="btn btn-ghost btn-sm">
            Dashboard
          </.link>
          <.link navigate={~p"/admin/users"} class="btn btn-ghost btn-sm">
            Users
          </.link>
          <.link navigate={~p"/admin/diagrams"} class="btn btn-ghost btn-sm">
            Diagrams
          </.link>
          <.link navigate={~p"/admin/documents"} class="btn btn-ghost btn-sm">
            Documents
          </.link>
          <.link navigate={~p"/admin/prompts"} class="btn btn-ghost btn-sm">
            Prompts
          </.link>
          <.link navigate={~p"/admin/usage/dashboard"} class="btn btn-ghost btn-sm btn-active">
            Usage
          </.link>
        </div>

        <Backpex.HTML.Layout.topbar_dropdown>
          <:label>
            <div class="btn btn-square btn-ghost">
              <Backpex.HTML.CoreComponents.icon name="hero-user" class="size-6" />
            </div>
          </:label>
          <li>
            <span class="text-sm text-base-content/70">
              {if assigns[:current_user], do: assigns.current_user.email}
            </span>
          </li>
          <li>
            <.link navigate={~p"/"} class="flex justify-between hover:bg-base-200">
              <p>Back to App</p>
              <Backpex.HTML.CoreComponents.icon name="hero-arrow-left" class="size-5" />
            </.link>
          </li>
          <li>
            <.link href="/auth/logout" class="text-error flex justify-between hover:bg-base-200">
              <p>Logout</p>
              <Backpex.HTML.CoreComponents.icon name="hero-arrow-right-on-rectangle" class="size-5" />
            </.link>
          </li>
        </Backpex.HTML.Layout.topbar_dropdown>
      </:topbar>
      <:sidebar>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/admin/dashboard"}>
          <Backpex.HTML.CoreComponents.icon name="hero-home" class="size-5" /> Dashboard
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/admin/users"}>
          <Backpex.HTML.CoreComponents.icon name="hero-users" class="size-5" /> Users
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/admin/diagrams"}>
          <Backpex.HTML.CoreComponents.icon name="hero-rectangle-group" class="size-5" /> Diagrams
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/admin/documents"}>
          <Backpex.HTML.CoreComponents.icon name="hero-document-text" class="size-5" /> Documents
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/admin/prompts"}>
          <Backpex.HTML.CoreComponents.icon name="hero-chat-bubble-bottom-center-text" class="size-5" />
          Prompts
        </Backpex.HTML.Layout.sidebar_item>

        <div class="divider my-2 text-xs text-base-content/50">API Usage</div>

        <Backpex.HTML.Layout.sidebar_item
          current_url={@current_url}
          navigate={~p"/admin/usage/dashboard"}
        >
          <Backpex.HTML.CoreComponents.icon name="hero-chart-bar" class="size-5" /> Usage Dashboard
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item
          current_url={@current_url}
          navigate={~p"/admin/usage/alerts"}
        >
          <Backpex.HTML.CoreComponents.icon name="hero-bell-alert" class="size-5" /> Alerts
          <span :if={@unacknowledged_count > 0} class="badge badge-error badge-sm ml-auto">
            {@unacknowledged_count}
          </span>
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item
          current_url={@current_url}
          navigate={~p"/admin/ai-providers"}
        >
          <Backpex.HTML.CoreComponents.icon name="hero-server" class="size-5" /> AI Providers
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/admin/ai-models"}>
          <Backpex.HTML.CoreComponents.icon name="hero-cpu-chip" class="size-5" /> AI Models
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item
          current_url={@current_url}
          navigate={~p"/admin/ai-model-prices"}
        >
          <Backpex.HTML.CoreComponents.icon name="hero-currency-dollar" class="size-5" /> Model Prices
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item
          current_url={@current_url}
          navigate={~p"/admin/alert-thresholds"}
        >
          <Backpex.HTML.CoreComponents.icon name="hero-adjustments-horizontal" class="size-5" />
          Thresholds
        </Backpex.HTML.Layout.sidebar_item>
      </:sidebar>
      <Backpex.HTML.Layout.flash_messages flash={@flash} />

      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-base-content">Usage Alerts</h1>
            <p class="mt-1 text-sm text-base-content/70">
              View and acknowledge usage threshold alerts
            </p>
          </div>
          <div class="flex items-center gap-2">
            <select
              name="filter"
              class="select select-sm select-bordered"
              phx-change="filter"
              id="alert-filter"
            >
              <option value="unacknowledged" selected={@filter == :unacknowledged}>
                Unacknowledged
              </option>
              <option value="acknowledged" selected={@filter == :acknowledged}>Acknowledged</option>
              <option value="all" selected={@filter == :all}>All</option>
            </select>
          </div>
        </div>
        <!-- Alerts List -->
        <div :if={@alerts == []} class="text-center py-12">
          <Backpex.HTML.CoreComponents.icon
            name="hero-check-circle"
            class="size-12 text-success mx-auto mb-4"
          />
          <p class="text-base-content/70">No alerts to display</p>
        </div>

        <div :if={@alerts != []} class="space-y-4">
          <div
            :for={alert <- @alerts}
            class={[
              "bg-base-100 rounded-lg border p-4 shadow-sm",
              !alert.acknowledged_at && "border-warning",
              alert.acknowledged_at && "border-base-300 opacity-75"
            ]}
            id={"alert-#{alert.id}"}
          >
            <div class="flex items-start justify-between">
              <div class="flex items-start gap-4">
                <div class={[
                  "p-2 rounded-lg",
                  !alert.acknowledged_at && "bg-warning/10",
                  alert.acknowledged_at && "bg-base-200"
                ]}>
                  <Backpex.HTML.CoreComponents.icon
                    name="hero-exclamation-triangle"
                    class={[
                      "size-6",
                      !alert.acknowledged_at && "text-warning",
                      alert.acknowledged_at && "text-base-content/50"
                    ]}
                  />
                </div>
                <div>
                  <h3 class="font-semibold text-base-content">
                    {alert.threshold.name}
                  </h3>
                  <p class="text-sm text-base-content/70 mt-1">
                    {scope_description(alert)}
                  </p>
                  <div class="flex items-center gap-4 mt-2 text-sm">
                    <span class="text-base-content/70">
                      Period: {alert.period_start} to {alert.period_end}
                    </span>
                    <span class="font-mono font-semibold text-error">
                      ${Usage.format_cents(alert.amount_cents)}
                    </span>
                    <span class="text-base-content/50">
                      (threshold: ${Usage.format_cents(alert.threshold.threshold_cents)})
                    </span>
                  </div>
                  <div :if={alert.acknowledged_at} class="mt-2 text-xs text-base-content/50">
                    Acknowledged by {alert.acknowledged_by && alert.acknowledged_by.email} on {Calendar.strftime(
                      alert.acknowledged_at,
                      "%Y-%m-%d %H:%M"
                    )}
                  </div>
                </div>
              </div>
              <div class="flex items-center gap-2">
                <span class="text-xs text-base-content/50">
                  {Calendar.strftime(alert.inserted_at, "%Y-%m-%d %H:%M")}
                </span>
                <button
                  :if={!alert.acknowledged_at}
                  phx-click="acknowledge"
                  phx-value-id={alert.id}
                  class="btn btn-sm btn-outline btn-success"
                >
                  <Backpex.HTML.CoreComponents.icon name="hero-check" class="size-4" /> Acknowledge
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Backpex.HTML.Layout.app_shell>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Usage Alerts")
     |> assign(:current_url, ~p"/admin/usage/alerts")
     |> assign(:filter, :unacknowledged)
     |> load_alerts()}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    filter_atom =
      case filter do
        "unacknowledged" -> :unacknowledged
        "acknowledged" -> :acknowledged
        "all" -> :all
        _ -> :unacknowledged
      end

    {:noreply,
     socket
     |> assign(:filter, filter_atom)
     |> load_alerts()}
  end

  @impl true
  def handle_event("acknowledge", %{"id" => id}, socket) do
    alert = Usage.get_alert(id)
    current_user = socket.assigns.current_user

    case Usage.acknowledge_alert(alert, current_user.id) do
      {:ok, _alert} ->
        {:noreply,
         socket
         |> put_flash(:info, "Alert acknowledged")
         |> load_alerts()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to acknowledge alert")}
    end
  end

  defp load_alerts(socket) do
    filter = socket.assigns.filter

    alerts =
      case filter do
        :unacknowledged -> Usage.list_alerts(acknowledged: false)
        :acknowledged -> Usage.list_alerts(acknowledged: true)
        :all -> Usage.list_alerts()
      end

    unacknowledged_count = Usage.count_unacknowledged_alerts()

    socket
    |> assign(:alerts, alerts)
    |> assign(:unacknowledged_count, unacknowledged_count)
  end

  defp scope_description(%{threshold: %{scope: "total"}}), do: "Total usage across all users"

  defp scope_description(%{threshold: %{scope: "per_user"}, user: nil}),
    do: "User usage (user deleted)"

  defp scope_description(%{threshold: %{scope: "per_user"}, user: user}),
    do: "Usage for #{user.email}"
end
