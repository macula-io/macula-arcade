defmodule MaculaArcade.Application do
  @moduledoc """
  OTP Application for MaculaArcade.

  Note: Database migrations are run via the release `start` script BEFORE
  this application boots. See `MaculaArcade.Release.migrate/0`.
  """

  use Application

  @impl true
  def start(_type, _args) do
    # Connect to Macula platform before starting children
    # This ensures the client PID is available when Coordinator starts
    {:ok, _client} = MaculaArcade.Mesh.connect()

    children =
      [
        # SQLite3 database for SnakeMaster persistence
        MaculaArcade.Repo,
        {DNSCluster, query: Application.get_env(:macula_arcade, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: MaculaArcade.PubSub},
        # Peer Identity - initializes local player and registers with distributed leaderboard
        MaculaArcade.PeerInit,
        # Matching System - handles player queue and match creation
        MaculaArcade.Matching.Service,
        # Gaming System - manages game lifecycles
        MaculaArcade.Gaming.Supervisor,
        # Dynamic supervisor for on-demand bot guests (Quick Games)
        {DynamicSupervisor, name: MaculaArcade.BotGuestSupervisor, strategy: :one_for_one}
      ] ++ bot_children()

    Supervisor.start_link(children, strategy: :one_for_one, name: MaculaArcade.Supervisor)
  end

  # Start bot clients if BOT_COUNT env var is set
  defp bot_children do
    case System.get_env("BOT_COUNT") do
      nil ->
        []

      "0" ->
        []

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
