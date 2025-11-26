defmodule MaculaArcade.SnakeMaster.TrainingSession do
  @moduledoc """
  Record of a TWEANN training session for a snake.

  Training types:
  - survival: Learn to avoid walls and other snakes
  - hunting: Learn to chase food efficiently
  - evasion: Learn to dodge enemy snakes
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias MaculaArcade.SnakeMaster.Snake

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @training_types ~w(survival hunting evasion)
  @statuses ~w(running completed cancelled)

  schema "training_sessions" do
    belongs_to :snake, Snake

    field :training_type, :string

    # Progress
    field :generations, :integer, default: 0
    field :best_fitness, :float, default: 0.0
    field :avg_fitness, :float, default: 0.0

    # Status
    field :status, :string, default: "running"

    # Duration
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @required_fields [:snake_id, :training_type]
  @optional_fields [:generations, :best_fitness, :avg_fitness, :status, :started_at, :completed_at]

  def changeset(session, attrs) do
    session
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:training_type, @training_types)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:snake_id)
  end

  def create_changeset(snake_id, training_type) do
    %__MODULE__{}
    |> changeset(%{
      snake_id: snake_id,
      training_type: training_type,
      started_at: DateTime.utc_now()
    })
  end

  def update_progress_changeset(session, generations, best_fitness, avg_fitness) do
    session
    |> cast(%{
      generations: generations,
      best_fitness: best_fitness,
      avg_fitness: avg_fitness
    }, [:generations, :best_fitness, :avg_fitness])
  end

  def complete_changeset(session) do
    session
    |> cast(%{
      status: "completed",
      completed_at: DateTime.utc_now()
    }, [:status, :completed_at])
  end

  def cancel_changeset(session) do
    session
    |> cast(%{
      status: "cancelled",
      completed_at: DateTime.utc_now()
    }, [:status, :completed_at])
  end

  def training_type_description("survival"), do: "Avoid walls & enemies"
  def training_type_description("hunting"), do: "Chase food efficiently"
  def training_type_description("evasion"), do: "Dodge enemy snakes"
  def training_type_description(_), do: "Unknown training"

  def training_type_emoji("survival"), do: "🛡️"
  def training_type_emoji("hunting"), do: "🎯"
  def training_type_emoji("evasion"), do: "💨"
  def training_type_emoji(_), do: "❓"
end
