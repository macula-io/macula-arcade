defmodule MaculaArcade.Repo.Migrations.AddPeerIdToPlayers do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :peer_id, :string
    end

    create unique_index(:players, [:peer_id], where: "peer_id IS NOT NULL")
  end
end
