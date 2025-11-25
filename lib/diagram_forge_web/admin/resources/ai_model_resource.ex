defmodule DiagramForgeWeb.Admin.AIModelResource do
  @moduledoc """
  Backpex resource for managing AI Models in the admin panel.
  """

  alias DiagramForge.Usage.AIModel

  use Backpex.LiveResource,
    adapter_config: [
      schema: AIModel,
      repo: DiagramForge.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3
    ],
    layout: {DiagramForgeWeb.Admin.Layouts, :admin}

  @doc false
  def changeset(item, attrs, _metadata) do
    AIModel.changeset(item, attrs)
  end

  @impl Backpex.LiveResource
  def singular_name, do: "AI Model"

  @impl Backpex.LiveResource
  def plural_name, do: "AI Models"

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
      provider: %{
        module: Backpex.Fields.BelongsTo,
        label: "Provider",
        display_field: :name,
        live_resource: DiagramForgeWeb.Admin.AIProviderResource
      },
      name: %{
        module: Backpex.Fields.Text,
        label: "Display Name",
        searchable: true
      },
      api_name: %{
        module: Backpex.Fields.Text,
        label: "API Name",
        searchable: true
      },
      capabilities: %{
        module: Backpex.Fields.Text,
        label: "Capabilities",
        render: fn assigns ->
          capabilities = assigns.value || []
          assigns = assign(assigns, :capabilities, capabilities)

          ~H"""
          <div class="flex flex-wrap gap-1">
            <span :for={cap <- @capabilities} class="badge badge-sm badge-outline">{cap}</span>
          </div>
          """
        end,
        only: [:index, :show]
      },
      is_active: %{
        module: Backpex.Fields.Boolean,
        label: "Active"
      },
      is_default: %{
        module: Backpex.Fields.Boolean,
        label: "Default"
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
