defmodule MaculaArcade.SnakeMaster.Snake do
  @moduledoc """
  A Snake owned by a SnakeMaster.

  Each snake has:
  - TWEANN configuration (preset or custom parameters)
  - Battle statistics (wins, losses, kills, etc.)
  - Visual appearance (colors, pattern)
  - TWEANN brain weights (evolved through training)

  ## TWEANN Presets

  Simple options for casual players:
  - **Hunter**: Aggressive pursuer - high mutation, low memory, high risk
  - **Survivor**: Defensive player - low mutation, high memory, low risk
  - **Chaotic**: Unpredictable - random all parameters
  - **Balanced**: Jack of all trades - medium all parameters

  ## Advanced TWEANN Parameters

  For enthusiasts who want fine control:
  - `mutation_rate`: How fast the brain evolves (0.01-0.5)
  - `memory_depth`: Ticks of game state remembered (1-10)
  - `risk_tolerance`: Willingness to take dangerous moves (0-100)
  - `exploration_rate`: Try new strategies vs exploit known (0-100)
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias MaculaArcade.SnakeMaster.Player
  alias MaculaArcade.SnakeMaster.MatchHistory
  alias MaculaArcade.SnakeMaster.TrainingSession

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(idle in_pit training)
  @patterns ~w(solid striped spotted gradient)
  @tweann_presets ~w(hunter survivor chaotic balanced custom)

  # TWEANN preset definitions
  @preset_configs %{
    "hunter" => %{
      mutation_rate: 0.3,
      memory_depth: 2,
      risk_tolerance: 80,
      exploration_rate: 70,
      description: "Aggressive pursuer - seeks out opponents"
    },
    "survivor" => %{
      mutation_rate: 0.05,
      memory_depth: 8,
      risk_tolerance: 20,
      exploration_rate: 30,
      description: "Defensive player - prioritizes survival"
    },
    "chaotic" => %{
      mutation_rate: 0.25,
      memory_depth: 5,
      risk_tolerance: 50,
      exploration_rate: 90,
      description: "Unpredictable - constantly evolving"
    },
    "balanced" => %{
      mutation_rate: 0.1,
      memory_depth: 5,
      risk_tolerance: 50,
      exploration_rate: 50,
      description: "Jack of all trades - adaptable"
    },
    "custom" => %{
      mutation_rate: 0.1,
      memory_depth: 5,
      risk_tolerance: 50,
      exploration_rate: 50,
      description: "Your custom configuration"
    }
  }

  schema "snakes" do
    belongs_to :player, Player

    field :name, :string

    # Personality traits (0-100)
    field :aggression, :integer, default: 50
    field :greed, :integer, default: 50
    field :caution, :integer, default: 50

    # TWEANN brain (serialized evolved weights)
    field :brain_weights, :binary

    # TWEANN configuration
    field :tweann_preset, :string, default: "balanced"
    field :tweann_mutation_rate, :float, default: 0.1
    field :tweann_memory_depth, :integer, default: 5
    field :tweann_risk_tolerance, :integer, default: 50
    field :tweann_exploration_rate, :integer, default: 50
    field :show_advanced_tweann, :boolean, default: false

    # Battle statistics
    field :wins, :integer, default: 0
    field :losses, :integer, default: 0
    field :draws, :integer, default: 0
    field :total_food_eaten, :integer, default: 0
    field :total_kills, :integer, default: 0
    field :longest_length, :integer, default: 3

    # Appearance
    field :color_primary, :string, default: "#22c55e"
    field :color_secondary, :string, default: "#16a34a"
    field :pattern, :string, default: "solid"

    # Status
    field :status, :string, default: "idle"

    has_many :match_history, MatchHistory
    has_many :training_sessions, TrainingSession

    timestamps(type: :utc_datetime)
  end

  @required_fields [:player_id, :name]
  @optional_fields [
    :aggression,
    :greed,
    :caution,
    :brain_weights,
    :tweann_preset,
    :tweann_mutation_rate,
    :tweann_memory_depth,
    :tweann_risk_tolerance,
    :tweann_exploration_rate,
    :show_advanced_tweann,
    :wins,
    :losses,
    :draws,
    :total_food_eaten,
    :total_kills,
    :longest_length,
    :color_primary,
    :color_secondary,
    :pattern,
    :status
  ]

  def changeset(snake, attrs) do
    snake
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 2, max: 20)
    |> validate_personality_trait(:aggression)
    |> validate_personality_trait(:greed)
    |> validate_personality_trait(:caution)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:pattern, @patterns)
    |> validate_inclusion(:tweann_preset, @tweann_presets)
    |> validate_number(:tweann_mutation_rate,
      greater_than_or_equal_to: 0.01,
      less_than_or_equal_to: 0.5
    )
    |> validate_number(:tweann_memory_depth,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 10
    )
    |> validate_number(:tweann_risk_tolerance,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> validate_number(:tweann_exploration_rate,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> validate_color(:color_primary)
    |> validate_color(:color_secondary)
    |> foreign_key_constraint(:player_id)
  end

  def create_changeset(player_id, attrs) do
    %__MODULE__{}
    |> changeset(Map.put(attrs, :player_id, player_id))
  end

  def update_stats_changeset(snake, %{result: result} = match_stats) do
    updates =
      case result do
        :won -> %{wins: snake.wins + 1}
        :lost -> %{losses: snake.losses + 1}
        :draw -> %{draws: snake.draws + 1}
      end

    updates =
      updates
      |> Map.put(:total_food_eaten, snake.total_food_eaten + Map.get(match_stats, :food_eaten, 0))
      |> Map.put(:total_kills, snake.total_kills + Map.get(match_stats, :kills, 0))
      |> maybe_update_longest_length(snake, match_stats)

    snake
    |> cast(updates, [:wins, :losses, :draws, :total_food_eaten, :total_kills, :longest_length])
  end

  def set_status_changeset(snake, status) when status in @statuses do
    snake
    |> cast(%{status: status}, [:status])
  end

  # Private helpers

  defp validate_personality_trait(changeset, field) do
    validate_number(changeset, field, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end

  defp validate_color(changeset, field) do
    validate_format(changeset, field, ~r/^#[0-9A-Fa-f]{6}$/, message: "must be a valid hex color")
  end

  defp maybe_update_longest_length(updates, snake, %{final_length: length})
       when length > snake.longest_length do
    Map.put(updates, :longest_length, length)
  end

  defp maybe_update_longest_length(updates, _snake, _match_stats), do: updates

  # Convenience functions

  def win_rate(%__MODULE__{wins: wins, losses: losses, draws: draws}) do
    total = wins + losses + draws

    case total do
      0 -> 0.0
      _ -> Float.round(wins / total * 100, 1)
    end
  end

  def total_matches(%__MODULE__{wins: wins, losses: losses, draws: draws}) do
    wins + losses + draws
  end

  def personality_summary(%__MODULE__{aggression: a, greed: g, caution: c}) do
    traits =
      []
      |> maybe_add_trait(a > 70, "aggressive")
      |> maybe_add_trait(a < 30, "passive")
      |> maybe_add_trait(g > 70, "greedy")
      |> maybe_add_trait(g < 30, "modest")
      |> maybe_add_trait(c > 70, "cautious")
      |> maybe_add_trait(c < 30, "reckless")

    case traits do
      [] -> "balanced"
      _ -> Enum.join(traits, ", ")
    end
  end

  defp maybe_add_trait(traits, true, trait), do: [trait | traits]
  defp maybe_add_trait(traits, false, _trait), do: traits

  # TWEANN preset functions

  @doc """
  Returns all available TWEANN presets.
  """
  def tweann_presets, do: @tweann_presets

  @doc """
  Returns the configuration for a specific preset.
  """
  def preset_config(preset) when preset in @tweann_presets do
    Map.get(@preset_configs, preset)
  end

  def preset_config(_), do: Map.get(@preset_configs, "balanced")

  @doc """
  Returns all preset configurations with their names.
  """
  def all_preset_configs, do: @preset_configs

  @doc """
  Applies a preset's TWEANN parameters to the given attributes.
  """
  def apply_preset(attrs, preset) when is_binary(preset) do
    config = preset_config(preset)

    attrs
    |> Map.put(:tweann_preset, preset)
    |> Map.put(:tweann_mutation_rate, config.mutation_rate)
    |> Map.put(:tweann_memory_depth, config.memory_depth)
    |> Map.put(:tweann_risk_tolerance, config.risk_tolerance)
    |> Map.put(:tweann_exploration_rate, config.exploration_rate)
  end

  @doc """
  Returns a human-readable summary of the TWEANN configuration.
  """
  def tweann_summary(%__MODULE__{tweann_preset: preset} = _snake) when preset != "custom" do
    config = preset_config(preset)
    String.capitalize(preset) <> " - " <> config.description
  end

  def tweann_summary(%__MODULE__{} = snake) do
    traits = []
    traits = if snake.tweann_risk_tolerance > 70, do: ["risky" | traits], else: traits
    traits = if snake.tweann_risk_tolerance < 30, do: ["careful" | traits], else: traits
    traits = if snake.tweann_exploration_rate > 70, do: ["exploratory" | traits], else: traits
    traits = if snake.tweann_exploration_rate < 30, do: ["focused" | traits], else: traits
    traits = if snake.tweann_mutation_rate > 0.25, do: ["evolving fast" | traits], else: traits
    traits = if snake.tweann_mutation_rate < 0.05, do: ["stable" | traits], else: traits

    case traits do
      [] -> "Custom - balanced configuration"
      _ -> "Custom - " <> Enum.join(traits, ", ")
    end
  end
end
