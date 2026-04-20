defmodule MaculaArcade.Repo.Migrations.AddAuthenticationToPlayers do
  use Ecto.Migration

  def change do
    alter table(:players) do
      # Authentication fields
      add :password_hash, :string

      # Optional email for future recovery
      add :email, :string

      # Profile display fields
      add :avatar_url, :string
      add :location, :string
      add :country_code, :string, size: 2
    end

    # Email must be unique if provided
    create unique_index(:players, [:email], where: "email IS NOT NULL")
  end
end
