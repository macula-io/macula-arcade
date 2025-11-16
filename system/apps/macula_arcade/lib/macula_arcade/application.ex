defmodule MaculaArcade.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # No database needed - arcade uses pure in-memory game state
      # MaculaArcade.Repo,
      # {Ecto.Migrator,
      #  repos: Application.fetch_env!(:macula_arcade, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:macula_arcade, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MaculaArcade.PubSub},
      MaculaArcade.Mesh.NodeManager,
      {DynamicSupervisor, name: MaculaArcade.GameSupervisor, strategy: :one_for_one},
      MaculaArcade.Games.Coordinator
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MaculaArcade.Supervisor)
  end
end
