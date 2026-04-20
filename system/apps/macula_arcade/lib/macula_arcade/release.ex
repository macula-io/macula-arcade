defmodule MaculaArcade.Release do
  @moduledoc """
  Release tasks for database migrations.

  Used for executing DB release tasks when run in production without Mix installed.
  This follows the Phoenix release overlay pattern for proper migration lifecycle.

  Note: SQLite requires special handling for schema_migrations table creation
  since it doesn't implement Ecto.Adapter.Storage.up/2 like PostgreSQL.

  Usage:
    bin/macula_arcade eval "MaculaArcade.Release.migrate"
    bin/macula_arcade eval "MaculaArcade.Release.rollback(MaculaArcade.Repo, 20251126232932)"
  """

  @app :macula_arcade

  @doc """
  Run all pending database migrations.
  """
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          # SQLite requires manual schema_migrations table creation
          ensure_schema_migrations_table(repo)
          Ecto.Migrator.run(repo, :up, all: true)
        end)
    end
  end

  @doc """
  Rollback database to a specific version.
  """
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  # SQLite doesn't create schema_migrations automatically like PostgreSQL
  # This creates it if missing
  defp ensure_schema_migrations_table(repo) do
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
