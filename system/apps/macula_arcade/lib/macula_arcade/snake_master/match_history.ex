defmodule MaculaArcade.SnakeMaster.MatchHistory do
  @moduledoc """
  Record of a single match between two snakes in the SnakePit.

  Stores match outcome, statistics, and optional replay data.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias MaculaArcade.SnakeMaster.Snake

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @results ~w(won lost draw)

  schema "match_history" do
    belongs_to :snake, Snake

    # Opponent info (snapshot)
    field :opponent_snake_id, :binary_id
    field :opponent_name, :string
    field :opponent_player_name, :string

    # Result
    field :result, :string

    # Match details
    field :my_score, :integer, default: 0
    field :opponent_score, :integer, default: 0
    field :my_final_length, :integer
    field :opponent_final_length, :integer
    field :duration_seconds, :integer
    field :food_eaten, :integer, default: 0
    field :kills, :integer, default: 0

    # Replay data
    field :replay_data, :binary

    timestamps(type: :utc_datetime)
  end

  @required_fields [:snake_id, :result]
  @optional_fields [
    :opponent_snake_id, :opponent_name, :opponent_player_name,
    :my_score, :opponent_score, :my_final_length, :opponent_final_length,
    :duration_seconds, :food_eaten, :kills, :replay_data
  ]

  def changeset(match, attrs) do
    match
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:result, @results)
    |> foreign_key_constraint(:snake_id)
  end

  def create_changeset(snake_id, attrs) do
    %__MODULE__{}
    |> changeset(Map.put(attrs, :snake_id, snake_id))
  end

  def result_emoji(%__MODULE__{result: "won"}), do: "🏆"
  def result_emoji(%__MODULE__{result: "lost"}), do: "💀"
  def result_emoji(%__MODULE__{result: "draw"}), do: "🤝"
end
