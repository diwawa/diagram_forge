defmodule DiagramForgeWeb.Admin.AlertThresholdResource do
  @moduledoc """
  Backpex resource for managing Usage Alert Thresholds in the admin panel.
  """

  alias DiagramForge.Usage.AlertThreshold

  use Backpex.LiveResource,
    adapter_config: [
      schema: AlertThreshold,
      repo: DiagramForge.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3
    ],
    layout: {DiagramForgeWeb.Admin.Layouts, :admin}

  @doc false
  def changeset(item, attrs, _metadata) do
    AlertThreshold.changeset(item, attrs)
  end

  @impl Backpex.LiveResource
  def singular_name, do: "Alert Threshold"

  @impl Backpex.LiveResource
  def plural_name, do: "Alert Thresholds"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{
        module: Backpex.Fields.Text,
        label: "ID",
        render: fn assigns ->
          short_id =
            assigns.value
            |> to_string()
            |> String.slice(0..7)

          assigns = assign(assigns, :short_id, short_id)

          ~H"""
          <span title={@value} class="font-mono text-xs">{@short_id}...</span>
          """
        end,
        only: [:index, :show]
      },
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true
      },
      threshold_cents: %{
        module: Backpex.Fields.Number,
        label: "Threshold",
        render: fn assigns ->
          cents = assigns.value || 0
          dollars = cents / 100

          assigns =
            assign(assigns, :formatted, "$#{:erlang.float_to_binary(dollars, decimals: 2)}")

          ~H"""
          <span class="font-mono font-semibold">{@formatted}</span>
          """
        end
      },
      period: %{
        module: Backpex.Fields.Select,
        label: "Period",
        options: [{"Daily", "daily"}, {"Monthly", "monthly"}]
      },
      scope: %{
        module: Backpex.Fields.Select,
        label: "Scope",
        options: [{"Per User", "per_user"}, {"Total", "total"}]
      },
      is_active: %{
        module: Backpex.Fields.Boolean,
        label: "Active"
      },
      notify_email: %{
        module: Backpex.Fields.Boolean,
        label: "Email Alerts"
      },
      notify_dashboard: %{
        module: Backpex.Fields.Boolean,
        label: "Dashboard Alerts"
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created",
        only: [:index, :show]
      },
      updated_at: %{
        module: Backpex.Fields.DateTime,
        label: "Updated",
        only: [:show]
      }
    ]
  end

  @impl Backpex.LiveResource
  def can?(assigns, :index, _item), do: superadmin?(assigns)
  def can?(assigns, :new, _item), do: superadmin?(assigns)
  def can?(assigns, :show, _item), do: superadmin?(assigns)
  def can?(assigns, :edit, _item), do: superadmin?(assigns)
  def can?(assigns, :delete, _item), do: superadmin?(assigns)
  def can?(_assigns, _action, _item), do: false

  defp superadmin?(assigns) do
    Map.get(assigns, :is_superadmin, false)
  end
end
