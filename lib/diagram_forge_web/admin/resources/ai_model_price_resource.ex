defmodule DiagramForgeWeb.Admin.AIModelPriceResource do
  @moduledoc """
  Backpex resource for managing AI Model Pricing in the admin panel.
  """

  alias DiagramForge.Usage.AIModelPrice

  use Backpex.LiveResource,
    adapter_config: [
      schema: AIModelPrice,
      repo: DiagramForge.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3
    ],
    layout: {DiagramForgeWeb.Admin.Layouts, :admin}

  @doc false
  def changeset(item, attrs, _metadata) do
    AIModelPrice.changeset(item, attrs)
  end

  @impl Backpex.LiveResource
  def singular_name, do: "Model Price"

  @impl Backpex.LiveResource
  def plural_name, do: "Model Prices"

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
      model: %{
        module: Backpex.Fields.BelongsTo,
        label: "Model",
        display_field: :name,
        live_resource: DiagramForgeWeb.Admin.AIModelResource
      },
      input_price_per_million: %{
        module: Backpex.Fields.Number,
        label: "Input Price ($/1M tokens)",
        render: fn assigns ->
          value = assigns.value || Decimal.new(0)
          assigns = assign(assigns, :formatted, "$#{Decimal.to_string(value)}")

          ~H"""
          <span class="font-mono">{@formatted}</span>
          """
        end
      },
      output_price_per_million: %{
        module: Backpex.Fields.Number,
        label: "Output Price ($/1M tokens)",
        render: fn assigns ->
          value = assigns.value || Decimal.new(0)
          assigns = assign(assigns, :formatted, "$#{Decimal.to_string(value)}")

          ~H"""
          <span class="font-mono">{@formatted}</span>
          """
        end
      },
      effective_from: %{
        module: Backpex.Fields.DateTime,
        label: "Effective From"
      },
      effective_until: %{
        module: Backpex.Fields.DateTime,
        label: "Effective Until"
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created",
        only: [:index, :show]
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
