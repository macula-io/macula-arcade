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
    ] ++ bot_children()

    Supervisor.start_link(children, strategy: :one_for_one, name: MaculaArcade.Supervisor)
  end

  # Start bot clients if BOT_COUNT env var is set
  defp bot_children do
    case System.get_env("BOT_COUNT") do
      nil -> []
      "0" -> []
      count_str ->
        count = String.to_integer(count_str)
        for i <- 1..count do
          Supervisor.child_spec(
            {MaculaArcade.Games.BotClient, [player_id: "bot_#{i}"]},
            id: {:bot_client, i}
          )
        end
    end
  end
end
