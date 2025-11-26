defmodule MaculaArcade.Repo.Migrations.CreateTrainingSessions do
  use Ecto.Migration

  def change do
    create table(:training_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :snake_id, references(:snakes, type: :binary_id, on_delete: :delete_all), null: false

      # Training type: survival, hunting, evasion
      add :training_type, :string, null: false

      # Progress
      add :generations, :integer, default: 0
      add :best_fitness, :float, default: 0.0
      add :avg_fitness, :float, default: 0.0

      # Status: running, completed, cancelled
      add :status, :string, default: "running"

      # Duration
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:training_sessions, [:snake_id])
    create index(:training_sessions, [:status])
  end
end
