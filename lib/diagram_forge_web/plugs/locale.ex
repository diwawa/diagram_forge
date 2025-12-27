defmodule DiagramForgeWeb.Plugs.Locale do
  @moduledoc """
  Plug to set the locale based on query params, session, or browser preferences.
  """
  import Plug.Conn

  def init(default_locale \\ "zh"), do: default_locale

  def call(conn, _default_locale) do
    # 强制设置为中文，忽略所有其他因素
    locale = "zh"

    Gettext.put_locale(DiagramForgeWeb.Gettext, locale)
    assign(conn, :locale, locale)
  end
end