defmodule MaculaArcade.Repo.Migrations.AddTweannConfigToSnakes do
  use Ecto.Migration

  @doc """
  Add TWEANN (Topology and Weight Evolving ANN) configuration to snakes.

  Presets provide simple options for casual players:
  - hunter: Aggressive pursuer
  - survivor: Defensive player
  - chaotic: Unpredictable
  - balanced: Jack of all trades

  Advanced parameters for enthusiasts:
  - mutation_rate: How fast the brain evolves (0.01-0.5)
  - memory_depth: Ticks of game state remembered (1-10)
  - risk_tolerance: Willingness to take dangerous moves (0-100)
  - exploration_rate: Try new strategies vs exploit known (0-100)
  """
  def change do
    alter table(:snakes) do
      # Preset selection (simple mode)
      add :tweann_preset, :string, default: "balanced"

      # Advanced TWEANN parameters
      add :tweann_mutation_rate, :float, default: 0.1
      add :tweann_memory_depth, :integer, default: 3
      add :tweann_risk_tolerance, :integer, default: 50
      add :tweann_exploration_rate, :integer, default: 50

      # UI state: show advanced panel
      add :show_advanced_tweann, :boolean, default: false
    end

    # Index for filtering by preset
    create index(:snakes, [:tweann_preset])
  end
end
