defmodule MaculaArcade.DistributedLeaderboard do
  @moduledoc """
  Distributed leaderboard using CRDTs for eventually-consistent stats across the mesh.

  Each peer can record match results locally, and stats automatically propagate
  to other peers via Macula's CRDT layer. The leaderboard is computed locally
  from the distributed state.

  ## Architecture

  Stats are stored as LWW-Register CRDTs with keys:
  - `leaderboard.player.{player_id}` - Player info (name, peer_id)
  - `leaderboard.snake.{snake_id}` - Snake stats (wins, losses, food_eaten, etc.)

  ## Eventually Consistent

  Because we use LWW-Registers (not G-Counters), concurrent updates to the same
  snake from different peers will result in last-write-wins semantics. For a
  game prototype this is acceptable - in production we'd want proper G-Counters.
  """

  require Logger
  alias MaculaArcade.Mesh

  @player_prefix "leaderboard.player."
  @snake_prefix "leaderboard.snake."
  @index_key "leaderboard.index"

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Register a player in the distributed leaderboard.
  Called when a peer starts and creates/loads its local player.
  """
  def register_player(player) do
    key = player_key(player.id)

    value = %{
      id: player.id,
      name: player.name,
      peer_id: player.peer_id,
      registered_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case Mesh.propose_crdt_update(key, value) do
      :ok ->
        add_to_index(:player, player.id)
        Logger.info("Registered player #{player.name} in distributed leaderboard")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to register player in distributed leaderboard: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Register a snake in the distributed leaderboard.
  Called when a snake is created.
  """
  def register_snake(snake, player) do
    key = snake_key(snake.id)

    value = %{
      id: snake.id,
      name: snake.name,
      player_id: player.id,
      player_name: player.name,
      head_color: snake.head_color,
      body_color: snake.body_color,
      wins: snake.wins,
      losses: snake.losses,
      total_food_eaten: snake.total_food_eaten,
      total_kills: snake.total_kills,
      max_length: snake.max_length,
      updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case Mesh.propose_crdt_update(key, value) do
      :ok ->
        add_to_index(:snake, snake.id)
        Logger.debug("Registered snake #{snake.name} in distributed leaderboard")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to register snake: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Record a match result in the distributed leaderboard.
  Updates both the winner's and loser's stats.
  """
  def record_match_result(winner_snake, loser_snake, match_stats) do
    # Update winner stats
    update_snake_stats(winner_snake.id, %{
      wins: winner_snake.wins + 1,
      total_food_eaten: winner_snake.total_food_eaten + (match_stats[:winner_food] || 0),
      total_kills: winner_snake.total_kills + (match_stats[:winner_kills] || 0),
      max_length: max(winner_snake.max_length, match_stats[:winner_max_length] || 0)
    })

    # Update loser stats
    update_snake_stats(loser_snake.id, %{
      losses: loser_snake.losses + 1,
      total_food_eaten: loser_snake.total_food_eaten + (match_stats[:loser_food] || 0),
      total_kills: loser_snake.total_kills + (match_stats[:loser_kills] || 0),
      max_length: max(loser_snake.max_length, match_stats[:loser_max_length] || 0)
    })

    :ok
  end

  @doc """
  Get the distributed leaderboard.
  Returns top snakes sorted by wins, then by losses (ascending), then by food eaten.
  """
  def get_leaderboard(limit \\ 10) do
    case get_index(:snake) do
      {:ok, snake_ids} ->
        snake_ids
        |> Enum.map(&get_snake_stats/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(fn stats -> stats.wins > 0 or stats.losses > 0 end)
        |> Enum.sort_by(fn stats -> {-stats.wins, stats.losses, -stats.total_food_eaten} end)
        |> Enum.take(limit)

      {:error, _} ->
        []
    end
  end

  @doc """
  Get global stats from the distributed leaderboard.
  """
  def get_global_stats do
    case get_index(:snake) do
      {:ok, snake_ids} ->
        stats =
          snake_ids
          |> Enum.map(&get_snake_stats/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.reduce(%{total_snakes: 0, total_matches: 0, total_food: 0}, fn snake, acc ->
            %{
              total_snakes: acc.total_snakes + 1,
              total_matches: acc.total_matches + snake.wins + snake.losses,
              total_food: acc.total_food + snake.total_food_eaten
            }
          end)

        # Divide matches by 2 since each match counts for both winner and loser
        %{stats | total_matches: div(stats.total_matches, 2)}

      {:error, _} ->
        %{total_snakes: 0, total_matches: 0, total_food: 0}
    end
  end

  @doc """
  Sync a local snake's stats to the distributed leaderboard.
  Called after local database updates to propagate changes.
  """
  def sync_snake(snake, player) do
    register_snake(snake, player)
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp player_key(player_id), do: @player_prefix <> to_string(player_id)
  defp snake_key(snake_id), do: @snake_prefix <> to_string(snake_id)

  defp update_snake_stats(snake_id, updates) do
    key = snake_key(snake_id)

    case Mesh.read_crdt(key) do
      {:ok, current_stats} when is_map(current_stats) ->
        updated_stats =
          Map.merge(current_stats, updates)
          |> Map.put(:updated_at, DateTime.utc_now() |> DateTime.to_iso8601())

        Mesh.propose_crdt_update(key, updated_stats)

      _ ->
        Logger.warning("Snake #{snake_id} not found in distributed leaderboard")
        {:error, :not_found}
    end
  end

  defp get_snake_stats(snake_id) do
    key = snake_key(snake_id)

    case Mesh.read_crdt(key) do
      {:ok, stats} when is_map(stats) ->
        # Ensure all required fields exist with defaults
        %{
          id: stats[:id] || stats["id"],
          name: stats[:name] || stats["name"] || "Unknown",
          player_id: stats[:player_id] || stats["player_id"],
          player_name: stats[:player_name] || stats["player_name"] || "Unknown",
          head_color: stats[:head_color] || stats["head_color"] || "#ffffff",
          body_color: stats[:body_color] || stats["body_color"] || "#cccccc",
          wins: stats[:wins] || stats["wins"] || 0,
          losses: stats[:losses] || stats["losses"] || 0,
          total_food_eaten: stats[:total_food_eaten] || stats["total_food_eaten"] || 0,
          total_kills: stats[:total_kills] || stats["total_kills"] || 0,
          max_length: stats[:max_length] || stats["max_length"] || 0
        }

      _ ->
        nil
    end
  end

  # Simple index management - stores list of IDs for each type
  # In production, this should use a proper distributed set CRDT

  defp add_to_index(type, id) do
    index_key = "#{@index_key}.#{type}"

    current_ids =
      case Mesh.read_crdt(index_key) do
        {:ok, ids} when is_list(ids) -> ids
        _ -> []
      end

    id_string = to_string(id)

    unless id_string in current_ids do
      Mesh.propose_crdt_update(index_key, [id_string | current_ids])
    end
  end

  defp get_index(type) do
    index_key = "#{@index_key}.#{type}"

    case Mesh.read_crdt(index_key) do
      {:ok, ids} when is_list(ids) -> {:ok, ids}
      {:ok, _} -> {:ok, []}
      {:error, :not_found} -> {:ok, []}
      error -> error
    end
  end
end
