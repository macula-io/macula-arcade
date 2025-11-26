defmodule MaculaArcade.Gaming.Supervisor do
  @moduledoc """
  Gaming Supervisor - manages game lifecycles.

  Responsibilities:
  - Start new games (DynamicSupervisor for GameServers)
  - Track active games
  - Coordinate game events via mesh pub/sub
  - Cleanup when games end

  This supervisor owns all running games. Each game is a separate
  GameServer process supervised by this module.
  """

  use GenServer
  require Logger
  alias MaculaArcade.Mesh
  alias MaculaArcade.Games.Snake.GameServer

  # Event topics
  @game_started_topic "arcade.snake.game_started"
  @game_ended_topic "arcade.snake.game_ended"

  defmodule State do
    @moduledoc false
    defstruct [
      :node_id,
      :subscriptions,
      active_games: %{}  # game_id => %{pid, players, started_at, is_host}
    ]
  end

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start a new game with two players.
  Called by Matching.Service when a match is confirmed.
  Returns {:ok, game_pid} or {:error, reason}.
  """
  def start_game(game_id, player1_id, player2_id) do
    GenServer.call(__MODULE__, {:start_game, game_id, player1_id, player2_id})
  end

  @doc """
  Get list of active games.
  """
  def list_games do
    GenServer.call(__MODULE__, :list_games)
  end

  @doc """
  Get game info by ID.
  """
  def get_game(game_id) do
    GenServer.call(__MODULE__, {:get_game, game_id})
  end

  @doc """
  Called when a game ends. Cleans up and notifies Matching.Service.
  """
  def game_ended(game_id, player1_id, player2_id, winner) do
    GenServer.cast(__MODULE__, {:game_ended, game_id, player1_id, player2_id, winner})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Gaming Supervisor starting")

    # Start the DynamicSupervisor for game processes
    {:ok, _} = DynamicSupervisor.start_link(
      strategy: :one_for_one,
      name: MaculaArcade.Gaming.GameDynamicSupervisor
    )

    # Schedule mesh initialization
    Process.send_after(self(), :initialize_mesh, 1000)

    {:ok, %State{}}
  end

  @impl true
  def handle_info(:initialize_mesh, state) do
    case initialize_mesh_connection(state) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, :not_connected} ->
        Logger.info("Mesh not connected yet, retrying in 1 second")
        Process.send_after(self(), :initialize_mesh, 1000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:mesh_event, @game_started_topic, event}, state) do
    handle_game_started_event(event, state)
  end

  @impl true
  def handle_info({:mesh_event, @game_ended_topic, event}, state) do
    handle_game_ended_event(event, state)
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Game process died - find and clean up
    game_entry = Enum.find(state.active_games, fn {_id, info} -> info.pid == pid end)

    case game_entry do
      {game_id, %{players: [p1, p2]}} ->
        Logger.warning("Game #{game_id} process died: #{inspect(reason)}")

        # Notify matching service that players are free
        MaculaArcade.Matching.Service.player_left_game(p1)
        MaculaArcade.Matching.Service.player_left_game(p2)

        new_games = Map.delete(state.active_games, game_id)
        {:noreply, %{state | active_games: new_games}}

      nil ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Call Handlers

  @impl true
  def handle_call({:start_game, game_id, player1_id, player2_id}, _from, state) do
    # Check if game already exists
    if Map.has_key?(state.active_games, game_id) do
      {:reply, {:error, :game_exists}, state}
    else
      # Start the game server
      case DynamicSupervisor.start_child(
        MaculaArcade.Gaming.GameDynamicSupervisor,
        {GameServer, [game_id: game_id]}
      ) do
        {:ok, game_pid} ->
          # Monitor the game process
          Process.monitor(game_pid)

          # Start the actual game
          {:ok, ^game_id} = GameServer.start_game(game_pid, player1_id, player2_id)

          # Get initial state for broadcast
          initial_state = GameServer.get_state(game_pid)

          # Track game
          game_info = %{
            pid: game_pid,
            players: [player1_id, player2_id],
            started_at: System.system_time(:second),
            is_host: true
          }

          new_games = Map.put(state.active_games, game_id, game_info)

          # Publish game_started event
          publish_game_started(game_id, player1_id, player2_id, initial_state, state.node_id)

          # Broadcast locally via Phoenix PubSub
          Phoenix.PubSub.broadcast(MaculaArcade.PubSub, "arcade.game.start", {
            :game_started,
            %{game_id: game_id, player1_id: player1_id, player2_id: player2_id}
          })

          Logger.info("Started game #{game_id}: #{player1_id} vs #{player2_id}")

          {:reply, {:ok, game_pid}, %{state | active_games: new_games}}

        {:error, reason} ->
          Logger.error("Failed to start game #{game_id}: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call(:list_games, _from, state) do
    games = Enum.map(state.active_games, fn {game_id, info} ->
      %{game_id: game_id, players: info.players, is_host: info.is_host}
    end)
    {:reply, games, state}
  end

  @impl true
  def handle_call({:get_game, game_id}, _from, state) do
    case Map.get(state.active_games, game_id) do
      nil -> {:reply, {:error, :not_found}, state}
      info -> {:reply, {:ok, info}, state}
    end
  end

  ## Cast Handlers

  @impl true
  def handle_cast({:game_ended, game_id, player1_id, player2_id, winner}, state) do
    Logger.info("Game #{game_id} ended. Winner: #{inspect(winner)}")

    # Notify matching service
    MaculaArcade.Matching.Service.player_left_game(player1_id)
    MaculaArcade.Matching.Service.player_left_game(player2_id)

    # Remove from active games
    new_games = Map.delete(state.active_games, game_id)

    # Publish game_ended event (if we're host)
    case Map.get(state.active_games, game_id) do
      %{is_host: true} ->
        publish_game_ended(game_id, player1_id, player2_id, winner, state.node_id)
      _ ->
        :ok
    end

    {:noreply, %{state | active_games: new_games}}
  end

  ## Event Handlers

  defp handle_game_started_event(event, state) do
    game_id = event["match_id"]
    host_node_id = event["host_node_id"]
    our_node_id_hex = encode_node_id(state.node_id)

    # Skip if we're the host (we already know about this game)
    if host_node_id == our_node_id_hex do
      {:noreply, state}
    else
      # We're a guest - track the game
      player1_id = event["initial_state"]["player1_id"]
      player2_id = event["initial_state"]["player2_id"]

      Logger.info("Received game_started for #{game_id} (we are guest)")

      game_info = %{
        pid: nil,  # No local process for guest
        players: [player1_id, player2_id],
        started_at: System.system_time(:second),
        is_host: false
      }

      new_games = Map.put(state.active_games, game_id, game_info)

      # Mark players as in-game (if they're ours)
      MaculaArcade.Matching.Service.player_joined_game(player1_id)
      MaculaArcade.Matching.Service.player_joined_game(player2_id)

      # Broadcast locally for UI updates
      Phoenix.PubSub.broadcast(MaculaArcade.PubSub, "arcade.game.start", {
        :game_started,
        %{game_id: game_id, player1_id: player1_id, player2_id: player2_id}
      })

      {:noreply, %{state | active_games: new_games}}
    end
  end

  defp handle_game_ended_event(event, state) do
    game_id = event["match_id"]
    player1_id = event["player1_id"]
    player2_id = event["player2_id"]

    Logger.info("Received game_ended for #{game_id}")

    # Notify matching service
    MaculaArcade.Matching.Service.player_left_game(player1_id)
    MaculaArcade.Matching.Service.player_left_game(player2_id)

    # Remove from tracking
    new_games = Map.delete(state.active_games, game_id)

    {:noreply, %{state | active_games: new_games}}
  end

  ## Mesh Helpers

  defp initialize_mesh_connection(state) do
    with {:ok, node_id} <- get_node_id(),
         {:ok, subs} <- subscribe_to_events() do

      Logger.info("Gaming Supervisor initialized on node #{encode_node_id(node_id)}")

      {:ok, %{state |
        node_id: node_id,
        subscriptions: subs
      }}
    end
  end

  defp get_node_id do
    try do
      client = Mesh.client()
      case :macula.get_node_id(client) do
        {:ok, id} -> {:ok, id}
        id when is_binary(id) -> {:ok, id}
        _ -> {:error, :not_connected}
      end
    catch
      :exit, _ -> {:error, :not_connected}
    rescue
      _ -> {:error, :not_connected}
    end
  end

  defp subscribe_to_events do
    supervisor_pid = self()
    client = Mesh.client()

    events = [@game_started_topic, @game_ended_topic]

    subs = Enum.reduce_while(events, [], fn topic, acc ->
      callback = fn payload ->
        send(supervisor_pid, {:mesh_event, topic, payload})
        :ok
      end

      case :macula.subscribe(client, topic, callback) do
        {:ok, ref} -> {:cont, [ref | acc]}
        {:error, :not_connected} -> {:halt, {:error, :not_connected}}
        {:error, reason} ->
          Logger.warning("Failed to subscribe to #{topic}: #{inspect(reason)}")
          {:cont, acc}
      end
    end)

    case subs do
      {:error, reason} -> {:error, reason}
      refs when is_list(refs) -> {:ok, refs}
    end
  end

  ## Publishing Helpers

  defp publish_game_started(game_id, _player1_id, _player2_id, initial_state, node_id) do
    Task.start(fn ->
      client = Mesh.client()
      :macula.publish(client, @game_started_topic, %{
        match_id: game_id,
        host_node_id: encode_node_id(node_id),
        initial_state: initial_state,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end)
  end

  defp publish_game_ended(game_id, player1_id, player2_id, winner, node_id) do
    Task.start(fn ->
      client = Mesh.client()
      :macula.publish(client, @game_ended_topic, %{
        match_id: game_id,
        player1_id: player1_id,
        player2_id: player2_id,
        winner: winner,
        host_node_id: encode_node_id(node_id),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end)
  end

  defp encode_node_id(node_id) when is_binary(node_id) do
    if byte_size(node_id) == 32 do
      Base.encode16(node_id, case: :lower)
    else
      node_id
    end
  end
  defp encode_node_id(node_id), do: node_id
end
