defmodule MaculaArcade.Games.Coordinator do
  @moduledoc """
  Game matchmaking coordinator using Macula pub/sub.

  Coordinates game creation and player matching:
  - Listens for players looking for games
  - Matches 2 players for Snake Battle Royale
  - Starts game servers
  - Broadcasts game start events
  """

  use GenServer
  require Logger
  alias MaculaArcade.Mesh.NodeManager
  alias MaculaArcade.Games.Snake.GameServer

  @matchmaking_topic "arcade.matchmaking.snake"
  @game_start_topic "arcade.game.start"

  defmodule State do
    defstruct [
      :waiting_players,
      :active_games,
      :subscription_ref
    ]
  end

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Player requests to join a game.
  """
  def join_queue(player_id) do
    GenServer.cast(__MODULE__, {:join_queue, player_id})
  end

  @doc """
  Player leaves the queue.
  """
  def leave_queue(player_id) do
    GenServer.cast(__MODULE__, {:leave_queue, player_id})
  end

  @doc """
  Gets list of active games.
  """
  def list_active_games do
    GenServer.call(__MODULE__, :list_active_games)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Game Coordinator starting")

    # Subscribe to matchmaking events on the mesh
    # Connection might not be ready yet, so retry if needed
    case NodeManager.subscribe(@matchmaking_topic, fn event_data ->
           handle_matchmaking_event(event_data)
           :ok
         end) do
      {:ok, sub_ref} ->
        Logger.info("Game Coordinator subscribed to #{@matchmaking_topic}")

        state = %State{
          waiting_players: [],
          active_games: %{},
          subscription_ref: sub_ref
        }

        {:ok, state}

      {:error, :not_connected} ->
        Logger.info(
          "Mesh not connected yet, will retry subscription in 1 second"
        )

        # Retry subscription after connection is established
        Process.send_after(self(), :retry_subscribe, 1000)

        state = %State{
          waiting_players: [],
          active_games: %{},
          subscription_ref: nil
        }

        {:ok, state}
    end
  end

  @impl true
  def handle_cast({:join_queue, player_id}, state) do
    Logger.info("Player #{player_id} joining queue")

    new_waiting = [player_id | state.waiting_players] |> Enum.uniq()
    Logger.info("Queue state: #{inspect(new_waiting)}, length: #{length(new_waiting)}")

    # Check if we can match players
    {matched_players, remaining_players} = match_players(new_waiting)
    Logger.info("Matched players: #{inspect(matched_players)}, remaining: #{inspect(remaining_players)}")

    new_state = %{state | waiting_players: remaining_players}

    # Create games for matched players
    new_state = Enum.reduce(matched_players, new_state, fn {p1, p2}, acc ->
      create_game(p1, p2, acc)
    end)

    # Publish to mesh for distributed coordination
    NodeManager.publish(@matchmaking_topic, %{
      type: "player_joined",
      player_id: player_id,
      queue_size: length(new_state.waiting_players)
    })

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:leave_queue, player_id}, state) do
    Logger.info("Player #{player_id} leaving queue")

    new_waiting = Enum.reject(state.waiting_players, &(&1 == player_id))

    # Publish to mesh
    NodeManager.publish(@matchmaking_topic, %{
      type: "player_left",
      player_id: player_id,
      queue_size: length(new_waiting)
    })

    {:noreply, %{state | waiting_players: new_waiting}}
  end

  @impl true
  def handle_cast({:mesh_player_joined, player_id}, state) do
    # Player joined from another node via mesh - add to local queue and attempt matching
    Logger.info("Adding player #{player_id} from mesh to local queue")

    new_waiting = [player_id | state.waiting_players] |> Enum.uniq()
    Logger.info("Queue state after mesh join: #{inspect(new_waiting)}, length: #{length(new_waiting)}")

    # Check if we can match players
    {matched_players, remaining_players} = match_players(new_waiting)

    new_state = %{state | waiting_players: remaining_players}

    # Create games for matched players
    new_state = Enum.reduce(matched_players, new_state, fn {p1, p2}, acc ->
      create_game(p1, p2, acc)
    end)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:mesh_player_left, player_id}, state) do
    # Player left from another node via mesh - remove from local queue
    Logger.info("Removing player #{player_id} from local queue (left on another node)")

    new_waiting = Enum.reject(state.waiting_players, &(&1 == player_id))

    {:noreply, %{state | waiting_players: new_waiting}}
  end

  @impl true
  def handle_cast({:mesh_match_created, player1_id, player2_id}, state) do
    # Match created on another node - remove matched players from local queue
    Logger.info("Removing matched players #{player1_id} and #{player2_id} from local queue")

    new_waiting = Enum.reject(state.waiting_players, &(&1 in [player1_id, player2_id]))

    {:noreply, %{state | waiting_players: new_waiting}}
  end

  @impl true
  def handle_call(:list_active_games, _from, state) do
    games = Enum.map(state.active_games, fn {game_id, %{players: players}} ->
      %{game_id: game_id, players: players}
    end)

    {:reply, games, state}
  end

  @impl true
  def handle_info(:retry_subscribe, state) do
    # Retry subscription after connection is established
    case NodeManager.subscribe(@matchmaking_topic, fn event_data ->
           handle_matchmaking_event(event_data)
           :ok
         end) do
      {:ok, sub_ref} ->
        Logger.info("Game Coordinator subscribed to #{@matchmaking_topic}")
        {:noreply, %{state | subscription_ref: sub_ref}}

      {:error, :not_connected} ->
        Logger.info(
          "Mesh still not connected, will retry subscription in 1 second"
        )

        Process.send_after(self(), :retry_subscribe, 1000)
        {:noreply, state}
    end
  end

  ## Private Functions

  defp handle_matchmaking_event(%{"type" => "player_joined", "player_id" => player_id}) do
    # Handle join events from other nodes via mesh
    Logger.info("Matchmaking event received from mesh: player #{player_id} joined")
    # Forward to local coordinator to add to queue
    GenServer.cast(__MODULE__, {:mesh_player_joined, player_id})
  end

  defp handle_matchmaking_event(%{"type" => "player_left", "player_id" => player_id}) do
    # Handle leave events from other nodes via mesh
    Logger.info("Matchmaking event received from mesh: player #{player_id} left")
    # Forward to local coordinator to remove from queue
    GenServer.cast(__MODULE__, {:mesh_player_left, player_id})
  end

  defp handle_matchmaking_event(%{"type" => "match_created", "player1_id" => p1, "player2_id" => p2}) do
    # Handle match creation events from other nodes via mesh
    Logger.info("Match created on another node: #{p1} vs #{p2}, removing from local queue")
    # Forward to local coordinator to remove matched players
    GenServer.cast(__MODULE__, {:mesh_match_created, p1, p2})
  end

  defp handle_matchmaking_event(event_data) do
    # Handle unknown events
    Logger.debug("Unknown matchmaking event received: #{inspect(event_data)}")
  end

  defp match_players(waiting_players) when length(waiting_players) < 2 do
    {[], waiting_players}
  end

  defp match_players([p1, p2 | rest]) do
    # Match first two players
    {[{p1, p2}], rest}
  end

  defp create_game(player1_id, player2_id, state) do
    Logger.info("Creating game for #{player1_id} vs #{player2_id}")

    # Start game server
    {:ok, game_pid} = DynamicSupervisor.start_child(
      MaculaArcade.GameSupervisor,
      {GameServer, [game_id: generate_game_id()]}
    )

    # Get game state
    {:ok, game_id} = GameServer.start_game(game_pid, player1_id, player2_id)

    # Broadcast match created via mesh (so other Coordinators remove these players from their queues)
    NodeManager.publish(@matchmaking_topic, %{
      type: "match_created",
      player1_id: player1_id,
      player2_id: player2_id,
      game_id: game_id
    })

    # Broadcast game start via mesh (for multi-container)
    NodeManager.publish(@game_start_topic, %{
      type: "game_started",
      game_id: game_id,
      player1_id: player1_id,
      player2_id: player2_id
    })

    # Also broadcast locally via Phoenix PubSub (for single-container)
    Phoenix.PubSub.broadcast(MaculaArcade.PubSub, @game_start_topic, {:game_started, %{
      game_id: game_id,
      player1_id: player1_id,
      player2_id: player2_id
    }})

    # Track game
    game_info = %{
      pid: game_pid,
      players: [player1_id, player2_id],
      started_at: System.system_time(:second)
    }

    %{state | active_games: Map.put(state.active_games, game_id, game_info)}
  end

  defp generate_game_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
