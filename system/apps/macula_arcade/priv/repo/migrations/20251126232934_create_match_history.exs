defmodule MaculaArcade.Repo.Migrations.CreateMatchHistory do
  use Ecto.Migration

  def change do
    create table(:match_history, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :snake_id, references(:snakes, type: :binary_id, on_delete: :delete_all), null: false

      # Opponent info (snapshot at time of match)
      add :opponent_snake_id, :binary_id
      add :opponent_name, :string
      add :opponent_player_name, :string

      # Result: won, lost, draw
      add :result, :string, null: false

      # Match details
      add :my_score, :integer, default: 0
      add :opponent_score, :integer, default: 0
      add :my_final_length, :integer
      add :opponent_final_length, :integer
      add :duration_seconds, :integer
      add :food_eaten, :integer, default: 0
      add :kills, :integer, default: 0

      # Optional replay data (compressed)
      add :replay_data, :binary

      timestamps(type: :utc_datetime)
    end

    create index(:match_history, [:snake_id])
    create index(:match_history, [:inserted_at])
  end
end
