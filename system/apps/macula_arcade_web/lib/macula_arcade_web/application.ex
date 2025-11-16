defmodule MaculaArcadeWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MaculaArcadeWeb.Telemetry,
      # Start a worker by calling: MaculaArcadeWeb.Worker.start_link(arg)
      # {MaculaArcadeWeb.Worker, arg},
      # Start to serve requests, typically the last entry
      MaculaArcadeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MaculaArcadeWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MaculaArcadeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
