defmodule DiagramForge.Repo do
  use Ecto.Repo,
    otp_app: :diagram_forge,
    adapter: Ecto.Adapters.Postgres
end
