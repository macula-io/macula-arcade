defmodule MaculaArcade.SnakeMaster.Snake do
  @moduledoc """
  A Snake owned by a SnakeMaster.

  Each snake has:
  - Personality traits (aggression, greed, caution) that affect behavior
  - Battle statistics (wins, losses, kills, etc.)
  - Visual appearance (colors, pattern)
  - TWEANN brain weights (for future AI training)
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

  schema "snakes" do
    belongs_to :player, Player

    field :name, :string

    # Personality traits (0-100)
    field :aggression, :integer, default: 50
    field :greed, :integer, default: 50
    field :caution, :integer, default: 50

    # TWEANN brain (serialized)
    field :brain_weights, :binary

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
    :aggression, :greed, :caution,
    :brain_weights,
    :wins, :losses, :draws, :total_food_eaten, :total_kills, :longest_length,
    :color_primary, :color_secondary, :pattern,
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
    |> validate_color(:color_primary)
    |> validate_color(:color_secondary)
    |> foreign_key_constraint(:player_id)
  end

  def create_changeset(player_id, attrs) do
    %__MODULE__{}
    |> changeset(Map.put(attrs, :player_id, player_id))
  end

  def update_stats_changeset(snake, %{result: result} = match_stats) do
    updates = case result do
      :won -> %{wins: snake.wins + 1}
      :lost -> %{losses: snake.losses + 1}
      :draw -> %{draws: snake.draws + 1}
    end

    updates = updates
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

  defp maybe_update_longest_length(updates, snake, %{final_length: length}) when length > snake.longest_length do
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
    traits = []
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
end
