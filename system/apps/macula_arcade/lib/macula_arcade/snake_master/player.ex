defmodule MaculaArcade.SnakeMaster.Player do
  @moduledoc """
  A SnakeMaster - the player who owns and trains snakes.

  Players earn coins through battles and reputation through victories.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias MaculaArcade.SnakeMaster.Snake

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "players" do
    field :name, :string
    field :coins, :integer, default: 100
    field :reputation, :integer, default: 0

    has_many :snakes, Snake

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name]
  @optional_fields [:coins, :reputation]

  def changeset(player, attrs) do
    player
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 2, max: 20)
    |> validate_number(:coins, greater_than_or_equal_to: 0)
    |> validate_number(:reputation, greater_than_or_equal_to: 0)
    |> unique_constraint(:name)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end
end
