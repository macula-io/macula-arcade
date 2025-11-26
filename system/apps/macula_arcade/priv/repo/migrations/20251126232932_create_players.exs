defmodule MaculaArcade.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :coins, :integer, default: 100
      add :reputation, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:players, [:name])
  end
end
