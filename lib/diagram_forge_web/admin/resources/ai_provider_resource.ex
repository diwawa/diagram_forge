defmodule DiagramForgeWeb.Admin.AIProviderResource do
  @moduledoc """
  Backpex resource for managing AI Providers in the admin panel.
  """

  alias DiagramForge.Usage.AIProvider

  use Backpex.LiveResource,
    adapter_config: [
      schema: AIProvider,
      repo: DiagramForge.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3
    ],
    layout: {DiagramForgeWeb.Admin.Layouts, :admin}

  @doc false
  def changeset(item, attrs, _metadata) do
    AIProvider.changeset(item, attrs)
  end

  @impl Backpex.LiveResource
  def singular_name, do: "AI Provider"

  @impl Backpex.LiveResource
  def plural_name, do: "AI Providers"

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
      slug: %{
        module: Backpex.Fields.Text,
        label: "Slug",
        searchable: true
      },
      api_base_url: %{
        module: Backpex.Fields.Text,
        label: "API Base URL"
      },
      is_active: %{
        module: Backpex.Fields.Boolean,
        label: "Active"
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
