defmodule MaculaArcade.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Run migrations before starting the application
    run_migrations()

    # Connect to Macula platform before starting children
    # This ensures the client PID is available when Coordinator starts
    {:ok, _client} = MaculaArcade.Mesh.connect()

    children = [
      # SQLite3 database for SnakeMaster persistence
      MaculaArcade.Repo,
      {DNSCluster, query: Application.get_env(:macula_arcade, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MaculaArcade.PubSub},
      # Matching System - handles player queue and match creation
      MaculaArcade.Matching.Service,
      # Gaming System - manages game lifecycles
      MaculaArcade.Gaming.Supervisor
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

  # Run Ecto migrations at application startup
  # Creates database if needed and runs all pending migrations
  defp run_migrations do
    require Logger

    # Get migrations path for the macula_arcade app
    migrations_path = Application.app_dir(:macula_arcade, "priv/repo/migrations")

    # with_repo starts a temporary repo connection for running migrations
    # The repo will be started properly as a child later
    {:ok, _, _} = Ecto.Migrator.with_repo(MaculaArcade.Repo, fn repo ->
      # Ensure schema_migrations table exists for SQLite3
      # SQLite will create the database file, but we need the table
      ensure_schema_migrations_table(repo)

      # Now run migrations
      Ecto.Migrator.run(repo, migrations_path, :up, all: true)
    end)

    Logger.info("Database migrations completed successfully")
  end

  # Create schema_migrations table if it doesn't exist (for SQLite)
  defp ensure_schema_migrations_table(repo) do
    # Check if table exists by trying a simple query
    try do
      Ecto.Adapters.SQL.query!(repo, "SELECT 1 FROM schema_migrations LIMIT 1", [])
    rescue
      _e in Exqlite.Error ->
        # Table doesn't exist, create it
        Ecto.Adapters.SQL.query!(
          repo,
          """
          CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            inserted_at TEXT
          )
          """,
          []
        )
    end
  end
end
