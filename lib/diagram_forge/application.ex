defmodule DiagramForge.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Set default locale to Chinese
    Gettext.put_locale(DiagramForgeWeb.Gettext, "zh")
    
    children = [
      DiagramForgeWeb.Telemetry,
      DiagramForge.Repo,
      DiagramForge.Vault,
      # Task supervisor for fire-and-forget tasks (e.g., usage tracking)
      {Task.Supervisor, name: DiagramForge.TaskSupervisor},
      # ETS cache for configurable prompts (supervised)
      DiagramForge.AI.CacheServer,
      {Oban, Application.fetch_env!(:diagram_forge, Oban)},
      {DNSCluster, query: Application.get_env(:diagram_forge, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DiagramForge.PubSub},
      # Start a worker by calling: DiagramForge.Worker.start_link(arg)
      # {DiagramForge.Worker, arg},
      # Start to serve requests, typically the last entry
      DiagramForgeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DiagramForge.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DiagramForgeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end