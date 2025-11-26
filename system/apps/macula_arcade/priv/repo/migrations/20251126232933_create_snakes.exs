defmodule MaculaArcade.Repo.Migrations.CreateSnakes do
  use Ecto.Migration

  def change do
    create table(:snakes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :player_id, references(:players, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false

      # Personality traits (0-100)
      add :aggression, :integer, default: 50
      add :greed, :integer, default: 50
      add :caution, :integer, default: 50

      # TWEANN brain (serialized binary - for future training)
      add :brain_weights, :binary

      # Battle statistics
      add :wins, :integer, default: 0
      add :losses, :integer, default: 0
      add :draws, :integer, default: 0
      add :total_food_eaten, :integer, default: 0
      add :total_kills, :integer, default: 0
      add :longest_length, :integer, default: 3

      # Appearance
      add :color_primary, :string, default: "#22c55e"
      add :color_secondary, :string, default: "#16a34a"
      add :pattern, :string, default: "solid"

      # Status: idle, in_pit, training
      add :status, :string, default: "idle"

      timestamps(type: :utc_datetime)
    end

    create index(:snakes, [:player_id])
    create index(:snakes, [:status])
  end
end
