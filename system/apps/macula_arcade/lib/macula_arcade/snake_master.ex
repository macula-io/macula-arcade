defmodule MaculaArcade.SnakeMaster do
  @moduledoc """
  The SnakeMaster context - manages players, snakes, and their activities.

  This is the primary API for:
  - Player registration and lookup
  - Snake creation and management
  - Match history tracking
  - Training session management
  """

  import Ecto.Query
  alias MaculaArcade.Repo
  alias MaculaArcade.SnakeMaster.{Player, Snake, MatchHistory, TrainingSession}

  # ============================================================================
  # Players
  # ============================================================================

  def get_player(id), do: Repo.get(Player, id)

  def get_player!(id), do: Repo.get!(Player, id)

  def get_player_by_name(name), do: Repo.get_by(Player, name: name)

  def get_or_create_player(name) do
    case get_player_by_name(name) do
      nil -> create_player(%{name: name})
      player -> {:ok, player}
    end
  end

  def create_player(attrs) do
    Player.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_player(%Player{} = player, attrs) do
    player
    |> Player.changeset(attrs)
    |> Repo.update()
  end

  def add_coins(%Player{} = player, amount) do
    update_player(player, %{coins: player.coins + amount})
  end

  def add_reputation(%Player{} = player, amount) do
    update_player(player, %{reputation: player.reputation + amount})
  end

  # ============================================================================
  # Snakes
  # ============================================================================

  def get_snake(id), do: Repo.get(Snake, id)

  def get_snake!(id), do: Repo.get!(Snake, id)

  def get_snake_with_player(id) do
    Snake
    |> Repo.get(id)
    |> Repo.preload(:player)
  end

  def list_snakes_for_player(player_id) do
    Snake
    |> where([s], s.player_id == ^player_id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc """
  Alias for list_snakes_for_player - returns all snakes for a player.
  """
  def list_player_snakes(player_id), do: list_snakes_for_player(player_id)

  def list_idle_snakes_for_player(player_id) do
    Snake
    |> where([s], s.player_id == ^player_id and s.status == "idle")
    |> order_by([s], desc: s.wins)
    |> Repo.all()
  end

  def count_snakes_for_player(player_id) do
    Snake
    |> where([s], s.player_id == ^player_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Get the top snakes by wins for the leaderboard.
  Tries distributed leaderboard first, falls back to local database.
  Returns snakes/stats with player info, ordered by wins descending.
  """
  def get_leaderboard(limit \\ 10) do
    # Try distributed leaderboard first
    case MaculaArcade.DistributedLeaderboard.get_leaderboard(limit) do
      [] ->
        # Fallback to local database if distributed is empty
        get_local_leaderboard(limit)

      distributed_entries ->
        distributed_entries
    end
  end

  @doc """
  Get the local leaderboard (just this peer's snakes).
  """
  def get_local_leaderboard(limit \\ 10) do
    Snake
    |> where([s], s.wins > 0 or s.losses > 0)
    |> order_by([s], desc: s.wins, asc: s.losses, desc: s.total_food_eaten)
    |> limit(^limit)
    |> preload(:player)
    |> Repo.all()
  end

  @doc """
  Get total stats across all snakes for display.
  Tries distributed leaderboard first, falls back to local database.
  """
  def get_global_stats do
    # Try distributed leaderboard first
    distributed_stats = MaculaArcade.DistributedLeaderboard.get_global_stats()

    case distributed_stats do
      %{total_snakes: 0} ->
        # Fallback to local database if distributed is empty
        get_local_global_stats()

      stats ->
        stats
    end
  end

  @doc """
  Get local stats (just this peer's snakes).
  """
  def get_local_global_stats do
    query =
      from s in Snake,
        select: %{
          total_snakes: count(s.id),
          total_matches: sum(s.wins) + sum(s.losses),
          total_food: sum(s.total_food_eaten)
        }

    Repo.one(query) || %{total_snakes: 0, total_matches: 0, total_food: 0}
  end

  def create_snake(player_id, attrs) do
    result =
      Snake.create_changeset(player_id, attrs)
      |> Repo.insert()

    # Register in distributed leaderboard (best-effort, async)
    register_snake_in_distributed_leaderboard(result, player_id)

    result
  end

  defp register_snake_in_distributed_leaderboard({:ok, snake}, player_id) do
    Task.start(fn ->
      case get_player(player_id) do
        nil ->
          :ok

        player ->
          MaculaArcade.DistributedLeaderboard.register_snake(snake, player)
      end
    end)
  end

  defp register_snake_in_distributed_leaderboard(_error, _player_id), do: :ok

  def update_snake(%Snake{} = snake, attrs) do
    snake
    |> Snake.changeset(attrs)
    |> Repo.update()
  end

  def set_snake_status(%Snake{} = snake, status) do
    snake
    |> Snake.set_status_changeset(status)
    |> Repo.update()
  end

  def update_snake_stats(%Snake{} = snake, match_stats) do
    snake
    |> Snake.update_stats_changeset(match_stats)
    |> Repo.update()
  end

  def delete_snake(%Snake{} = snake) do
    Repo.delete(snake)
  end

  # ============================================================================
  # Match History
  # ============================================================================

  def get_match_history(id), do: Repo.get(MatchHistory, id)

  def list_match_history_for_snake(snake_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    MatchHistory
    |> where([m], m.snake_id == ^snake_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def record_match(snake_id, attrs) do
    MatchHistory.create_changeset(snake_id, attrs)
    |> Repo.insert()
  end

  def record_match_and_update_stats(snake, opponent_snake, result, match_data) do
    result =
      Repo.transaction(fn ->
        # Create match history record
        match_attrs = %{
          opponent_snake_id: opponent_snake.id,
          opponent_name: opponent_snake.name,
          opponent_player_name: opponent_snake.player.name,
          result: to_string(result),
          my_score: match_data[:my_score] || 0,
          opponent_score: match_data[:opponent_score] || 0,
          my_final_length: match_data[:my_final_length],
          opponent_final_length: match_data[:opponent_final_length],
          duration_seconds: match_data[:duration_seconds],
          food_eaten: match_data[:food_eaten] || 0,
          kills: match_data[:kills] || 0,
          replay_data: match_data[:replay_data]
        }

        {:ok, _match} = record_match(snake.id, match_attrs)

        # Update snake stats
        stats = %{
          result: result,
          food_eaten: match_data[:food_eaten] || 0,
          kills: match_data[:kills] || 0,
          final_length: match_data[:my_final_length] || 0
        }

        {:ok, updated_snake} = update_snake_stats(snake, stats)
        updated_snake
      end)

    # Sync to distributed leaderboard after local transaction
    sync_to_distributed_leaderboard(result, snake, match_data)

    result
  end

  # Sync updated stats to distributed leaderboard (best-effort, async)
  defp sync_to_distributed_leaderboard({:ok, updated_snake}, _snake, _match_data) do
    Task.start(fn ->
      # Reload snake with player to get full data
      case get_snake_with_player(updated_snake.id) do
        nil ->
          :ok

        snake_with_player ->
          MaculaArcade.DistributedLeaderboard.sync_snake(
            snake_with_player,
            snake_with_player.player
          )
      end
    end)
  end

  defp sync_to_distributed_leaderboard(_error, _snake, _match_data), do: :ok

  # ============================================================================
  # Training Sessions
  # ============================================================================

  def get_training_session(id), do: Repo.get(TrainingSession, id)

  def list_training_sessions_for_snake(snake_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    TrainingSession
    |> where([t], t.snake_id == ^snake_id)
    |> order_by([t], desc: t.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_running_training_session(snake_id) do
    TrainingSession
    |> where([t], t.snake_id == ^snake_id and t.status == "running")
    |> Repo.one()
  end

  def start_training_session(snake_id, training_type) do
    Repo.transaction(fn ->
      snake = get_snake!(snake_id)

      case snake.status do
        "idle" ->
          {:ok, _} = set_snake_status(snake, "training")

          TrainingSession.create_changeset(snake_id, training_type)
          |> Repo.insert!()

        _ ->
          Repo.rollback(:snake_not_idle)
      end
    end)
  end

  def update_training_progress(session, generations, best_fitness, avg_fitness) do
    session
    |> TrainingSession.update_progress_changeset(generations, best_fitness, avg_fitness)
    |> Repo.update()
  end

  def complete_training_session(session) do
    Repo.transaction(fn ->
      snake = get_snake!(session.snake_id)
      {:ok, _} = set_snake_status(snake, "idle")

      session
      |> TrainingSession.complete_changeset()
      |> Repo.update!()
    end)
  end

  def cancel_training_session(session) do
    Repo.transaction(fn ->
      snake = get_snake!(session.snake_id)
      {:ok, _} = set_snake_status(snake, "idle")

      session
      |> TrainingSession.cancel_changeset()
      |> Repo.update!()
    end)
  end
end
