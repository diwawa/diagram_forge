defmodule DiagramForgeWeb.Admin.Layouts do
  @moduledoc """
  Custom layouts for the admin panel.
  """

  use DiagramForgeWeb, :html

  embed_templates "layouts/*"

  @doc """
  Navigation link component for admin panel.
  """
  attr :navigate, :string, required: true
  slot :inner_block, required: true

  def admin_nav_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="rounded-md px-3 py-2 text-sm font-medium hover:bg-base-200"
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders flash messages with auto-dismiss functionality.

  Flash messages automatically dismiss after 10 seconds (configurable via dismiss_after).
  This solves the issue where consecutive bulk actions would show stale flash messages.
  """
  attr :flash, :map, required: true
  attr :dismiss_after, :integer, default: 10_000

  def auto_dismiss_flash_messages(assigns) do
    ~H"""
    <div aria-live="polite">
      <div
        :for={kind <- ~w(info success warning error)a}
        :if={msg = Phoenix.Flash.get(@flash, kind)}
        id={"flash-#{kind}"}
        phx-hook="AutoDismissFlash"
        data-dismiss-after={@dismiss_after}
        data-flash-key={kind}
      >
        <Backpex.HTML.Layout.alert
          kind={kind}
          on_close={Phoenix.LiveView.JS.push("lv:clear-flash", value: %{key: kind})}
        >
          {msg}
        </Backpex.HTML.Layout.alert>
      </div>
    </div>
    """
  end
end
