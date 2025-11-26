defmodule MaculaArcade.Games.Coordinator do
  @moduledoc """
  Game matchmaking coordinator using Macula DHT pub/sub and RPC.

  Implements the Snake Duel Protocol v0.2.0:
  - Decentralized matchmaking via DHT
  - Event-driven state transitions
  - Cross-peer game coordination

  See docs/SNAKE_DUEL_PROTOCOL.md for full specification.
  """

  use GenServer
  require Logger
  alias MaculaArcade.Mesh
  alias MaculaArcade.Games.Snake.GameServer

  # Event topics (past tense - things that happened)
  @player_registered_topic "arcade.snake.player_registered"
  @player_unregistered_topic "arcade.snake.player_unregistered"
  @match_proposed_topic "arcade.snake.match_proposed"
  @match_found_topic "arcade.snake.match_found"
  @game_started_topic "arcade.snake.game_started"
  @state_updated_topic "arcade.snake.state_updated"
  @game_ended_topic "arcade.snake.game_ended"

  # RPC procedures (imperative - actions to perform)
  @register_player_proc "arcade.snake.register_player"
  @unregister_player_proc "arcade.snake.unregister_player"
  @find_opponents_proc "arcade.snake.find_opponents"
  @submit_action_proc "arcade.snake.submit_action"

  # DHT key for player queue
  @queue_dht_key "arcade.snake.queue"

  defmodule State do
    @moduledoc false
    defstruct [
      :node_id,
      :leader_node_id,       # Current Raft leader (from Platform Layer)
      :is_leader,            # Boolean: are we the leader?
      :waiting_players,      # Map of player_id => %{timestamp, player_name, node_id}
      :remote_players,       # Map of player_id => %{timestamp, player_name, node_id} - players on other nodes
      :pending_matches,      # Map of match_id => %{player1, player2, timestamp}
      :active_games,         # Map of game_id => %{pid, players, started_at}
      :players_in_game,      # MapSet of player IDs in active games
      :subscriptions         # List of subscription refs
    ]
  end

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register player for matchmaking.
  Called when player clicks "Insert Coin".
  """
  def register_player(player_id, player_name \\ nil) do
    GenServer.call(__MODULE__, {:register_player, player_id, player_name || player_id})
  end

  @doc """
  Unregister player from matchmaking.
  """
  def unregister_player(player_id) do
    GenServer.call(__MODULE__, {:unregister_player, player_id})
  end

  @doc """
  Get current queue status.
  """
  def get_queue_status do
    GenServer.call(__MODULE__, :get_queue_status)
  end

  @doc """
  Gets list of active games.
  """
  def list_active_games do
    GenServer.call(__MODULE__, :list_active_games)
  end

  @doc """
  Notifies that a game has ended, removing players from in_game set.
  Called by GameServer when game finishes.
  """
  def game_ended(game_id, player1_id, player2_id, winner) do
    GenServer.cast(__MODULE__, {:game_ended, game_id, player1_id, player2_id, winner})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Game Coordinator starting (Snake Duel Protocol v0.2.0)")

    # Schedule initialization after mesh connects
    Process.send_after(self(), :initialize_mesh, 1000)

    state = %State{
      node_id: nil,
      leader_node_id: nil,
      is_leader: false,
      waiting_players: %{},
      remote_players: %{},
      pending_matches: %{},
      active_games: %{},
      players_in_game: MapSet.new(),
      subscriptions: []
    }

    {:ok, state}
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
  def handle_info({:mesh_event, topic, payload}, state) do
    handle_mesh_event(topic, payload, state)
  end

  @impl true
  def handle_info(:attempt_matchmaking, state) do
    new_state = attempt_matchmaking(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:leader_changed, change}, state) do
    old_leader = change.old_leader || change["old_leader"]
    new_leader = change.new_leader || change["new_leader"]

    was_leader = state.is_leader
    is_leader_now = (new_leader == state.node_id)

    Logger.info("Leader changed: #{inspect_node_id(old_leader)} -> #{inspect_node_id(new_leader)}")
    Logger.info("We were leader: #{was_leader}, We are leader now: #{is_leader_now}")

    new_state = %{state |
      leader_node_id: new_leader,
      is_leader: is_leader_now
    }

    # If we just became leader, we might want to trigger matchmaking
    new_state = if not was_leader and is_leader_now do
      Logger.info("We are now the leader - triggering matchmaking")
      attempt_matchmaking(new_state)
    else
      new_state
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:game_ended, game_id, player1_id, player2_id, winner}, state) do
    Logger.info("Game #{game_id} ended, winner: #{inspect(winner)}")

    # Remove players from in_game set
    new_players_in_game = state.players_in_game
    |> MapSet.delete(player1_id)
    |> MapSet.delete(player2_id)

    # Remove from active games
    new_active_games = Map.delete(state.active_games, game_id)

    {:noreply, %{state |
      players_in_game: new_players_in_game,
      active_games: new_active_games
    }}
  end

  ## Client Handlers

  @impl true
  def handle_call({:register_player, player_id, player_name}, _from, state) do
    cond do
      MapSet.member?(state.players_in_game, player_id) ->
        {:reply, {:error, :in_game}, state}

      Map.has_key?(state.waiting_players, player_id) ->
        {:reply, {:error, :already_registered}, state}

      true ->
        timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

        # Add to local queue
        player_info = %{
          player_id: player_id,
          player_name: player_name,
          node_id: state.node_id,
          timestamp: timestamp
        }

        new_waiting = Map.put(state.waiting_players, player_id, player_info)

        # Store in DHT
        store_player_in_dht(player_info)

        # Publish player_registered event (with hex-encoded node_id for JSON)
        event_payload = Map.put(player_info, :node_id, encode_node_id(state.node_id))
        Task.start(fn -> publish_event(@player_registered_topic, event_payload) end)

        Logger.info("Player #{player_id} registered for matchmaking")

        new_state = %{state | waiting_players: new_waiting}
        queue_position = map_size(new_waiting)

        # Don't do immediate local matchmaking here - let the event-driven system handle it
        # When other nodes receive our player_registered event, they'll propose matches
        # This prevents race conditions where both peers try to create separate games

        {:reply, {:ok, %{queue_position: queue_position}}, new_state}
    end
  end

  @impl true
  def handle_call({:unregister_player, player_id}, _from, state) do
    case Map.get(state.waiting_players, player_id) do
      nil ->
        {:reply, {:error, :not_registered}, state}

      _player_info ->
        new_waiting = Map.delete(state.waiting_players, player_id)

        # Remove from DHT
        remove_player_from_dht(player_id)

        # Publish player_unregistered event
        publish_event(@player_unregistered_topic, %{
          player_id: player_id,
          node_id: encode_node_id(state.node_id),
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          reason: "cancelled"
        })

        Logger.info("Player #{player_id} unregistered from matchmaking")

        {:reply, :ok, %{state | waiting_players: new_waiting}}
    end
  end

  @impl true
  def handle_call(:get_queue_status, _from, state) do
    status = %{
      queue_size: map_size(state.waiting_players),
      players: Map.keys(state.waiting_players),
      active_games: map_size(state.active_games)
    }
    {:reply, status, state}
  end

  @impl true
  def handle_call(:list_active_games, _from, state) do
    games =
      Enum.map(state.active_games, fn {game_id, %{players: players}} ->
        %{game_id: game_id, players: players}
      end)

    {:reply, games, state}
  end

  ## Private Functions

  defp initialize_mesh_connection(state) do
    with {:ok, node_id} <- get_node_id(),
         {:ok, leader_info} <- get_leader_info(node_id),
         :ok <- subscribe_to_leader_changes(),
         :ok <- register_rpc_handlers(),
         {:ok, subs} <- subscribe_to_events() do

      Logger.info("Game Coordinator initialized on node #{inspect_node_id(node_id)}")
      Logger.info("Current leader: #{inspect_node_id(leader_info.leader_node_id)}, We are leader: #{leader_info.is_leader}")

      {:ok, %{state |
        node_id: node_id,
        leader_node_id: leader_info.leader_node_id,
        is_leader: leader_info.is_leader,
        subscriptions: subs
      }}
    end
  end

  defp get_node_id do
    try do
      client = Mesh.client()
      try do
        case :macula.get_node_id(client) do
          {:ok, id} -> {:ok, id}
          id when is_binary(id) -> {:ok, id}
          _ -> {:error, :not_connected}
        end
      catch
        :exit, _ -> {:error, :not_connected}
      end
    rescue
      _ -> {:error, :not_connected}
    end
  end

  defp get_leader_info(our_node_id) do
    case Mesh.get_leader() do
      {:ok, leader_node_id} ->
        is_leader = (leader_node_id == our_node_id)
        {:ok, %{leader_node_id: leader_node_id, is_leader: is_leader}}

      {:error, :no_leader} ->
        Logger.warning("No Raft leader elected yet")
        {:ok, %{leader_node_id: nil, is_leader: false}}

      {:error, reason} ->
        Logger.error("Failed to get leader: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp subscribe_to_leader_changes do
    coordinator_pid = self()

    case Mesh.subscribe_leader_changes(fn change ->
      send(coordinator_pid, {:leader_changed, change})
      :ok
    end) do
      {:ok, _ref} ->
        Logger.info("Subscribed to leader changes")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to subscribe to leader changes: #{inspect(reason)}")
        :ok  # Non-critical, continue anyway
    end
  end

  defp register_rpc_handlers do
    # Register handler for register_player RPC
    register_handler = fn args ->
      handle_register_player_rpc(args)
    end

    # Register handler for find_opponents RPC
    find_handler = fn args ->
      handle_find_opponents_rpc(args)
    end

    # Register handler for submit_action RPC
    action_handler = fn args ->
      handle_submit_action_rpc(args)
    end

    client = Mesh.client()
    with {:ok, _} <- :macula.advertise(client, @register_player_proc, register_handler),
         {:ok, _} <- :macula.advertise(client, @find_opponents_proc, find_handler),
         {:ok, _} <- :macula.advertise(client, @submit_action_proc, action_handler) do
      Logger.info("Registered RPC handlers for Snake Duel")
      :ok
    else
      {:error, reason} ->
        Logger.warning("Failed to register RPC handlers: #{inspect(reason)}")
        # Continue anyway - local play will still work
        :ok
    end
  end

  defp subscribe_to_events do
    coordinator_pid = self()
    client = Mesh.client()

    events = [
      @player_registered_topic,
      @player_unregistered_topic,
      @match_proposed_topic,
      @match_found_topic,
      @game_started_topic,
      @game_ended_topic
    ]

    subs = Enum.reduce_while(events, [], fn topic, acc ->
      callback = fn payload ->
        send(coordinator_pid, {:mesh_event, topic, payload})
        :ok
      end

      case :macula.subscribe(client, topic, callback) do
        {:ok, ref} ->
          {:cont, [ref | acc]}

        {:error, :not_connected} ->
          {:halt, {:error, :not_connected}}

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

  ## Event Handlers

  defp handle_mesh_event(@player_registered_topic, event, state) do
    # Another player registered - add to remote players and attempt matching
    # Note: 'event' IS the payload directly from the subscription callback
    Logger.info("Received player_registered event: #{inspect(event)}")

    # Extract player data directly from event (no payload wrapper)
    player_id = event["player_id"]
    their_node_id = event["node_id"]
    our_node_id_hex = encode_node_id(state.node_id)

    Logger.info("Node ID comparison: ours=#{our_node_id_hex} theirs=#{their_node_id}")

    # Add to remote_players map (even if it's our own node!)
    # The Coordinator needs to collect ALL players from ALL nodes for matchmaking
    new_remote_players = Map.put(state.remote_players, player_id, event)
    new_state = %{state | remote_players: new_remote_players}

    Logger.info("Added player #{player_id} from node #{their_node_id} (total remote: #{map_size(new_remote_players)})")

    # Attempt to match with local waiting players
    new_state = attempt_cross_peer_matchmaking(new_state)

    {:noreply, new_state}
  end

  defp handle_mesh_event(@player_unregistered_topic, event, state) do
    # Remote player unregistered - remove from remote_players
    # Note: 'event' IS the payload directly from the subscription callback
    Logger.info("Received player_unregistered event: #{inspect(event)}")

    # Extract data directly from event (no payload wrapper)
    player_id = event["player_id"]
    their_node_id = event["node_id"]
    our_node_id_hex = encode_node_id(state.node_id)

    if their_node_id != our_node_id_hex do
      # Remove from remote_players map
      new_remote_players = Map.delete(state.remote_players, player_id)

      Logger.info("Removed remote player #{player_id} from node #{their_node_id}")

      {:noreply, %{state | remote_players: new_remote_players}}
    else
      {:noreply, state}
    end
  end

  defp handle_mesh_event(@match_proposed_topic, event, state) do
    handle_match_proposal(event[:payload], state)
  end

  defp handle_mesh_event(@match_found_topic, event, state) do
    handle_match_found(event[:payload], state)
  end

  defp handle_mesh_event(@game_started_topic, event, state) do
    payload = event[:payload]
    match_id = payload["match_id"]
    host_node_id = payload["host_node_id"]
    our_node_id_hex = encode_node_id(state.node_id)

    # Skip if we're the host - we already broadcast to Phoenix PubSub in start_game_as_host
    if host_node_id == our_node_id_hex do
      Logger.debug("We are host for game #{match_id}, skipping mesh event broadcast")
      {:noreply, state}
    else
      Logger.info("Game started: #{match_id} (we are guest)")

      # Extract player IDs from initial_state if available
      initial_state = payload["initial_state"]
      player1_id = initial_state["player1_id"]
      player2_id = initial_state["player2_id"]

      # IMPORTANT: Guest does NOT start a local GameServer!
      # The host's GameServer broadcasts state via mesh pub/sub.
      # Guest LiveViews subscribe to mesh topics and receive state updates.
      # Starting a local GameServer would create a duplicate game with different state.

      Logger.info("Guest will receive game state from host via mesh for game #{match_id}")

      # Broadcast to local Phoenix PubSub for UI updates
      # This ensures guests' LiveViews know the game started and can subscribe to state
      Phoenix.PubSub.broadcast(MaculaArcade.PubSub, "arcade.game.start", {
        :game_started,
        %{
          game_id: match_id,
          player1_id: player1_id,
          player2_id: player2_id
        }
      })

      # Mark players as in game if they're ours
      new_players_in_game = state.players_in_game
      |> maybe_add_player(player1_id, state.waiting_players)
      |> maybe_add_player(player2_id, state.waiting_players)

      # Remove from waiting if they were ours
      new_waiting = state.waiting_players
      |> Map.delete(player1_id)
      |> Map.delete(player2_id)

      # Track game (no local pid since we're guest)
      game_info = %{
        pid: nil,  # No local GameServer for guest
        players: [player1_id, player2_id],
        started_at: System.system_time(:second),
        is_guest: true
      }

      {:noreply, %{state |
        players_in_game: new_players_in_game,
        waiting_players: new_waiting,
        active_games: Map.put(state.active_games, match_id, game_info)
      }}
    end
  end

  defp handle_mesh_event(@game_ended_topic, event, state) do
    handle_game_ended(event[:payload], state)
  end

  defp handle_mesh_event(topic, event, state) do
    Logger.debug("Unhandled mesh event #{topic}: #{inspect(event)}")
    {:noreply, state}
  end

  ## Matchmaking Logic

  defp attempt_matchmaking(state) do
    # First try cross-peer matching (faster than DHT query)
    attempt_cross_peer_matchmaking(state)
  end

  defp attempt_cross_peer_matchmaking(state) do
    # Match local waiting player with remote waiting player
    case {get_first_waiting_player(state), get_first_remote_player(state)} do
      {nil, _} ->
        # No local players waiting
        state

      {_, nil} ->
        # No remote players, try DHT fallback
        attempt_dht_matchmaking(state)

      {{_local_id, local_player}, {_remote_id, remote_player}} ->
        # Match found! Propose it
        Logger.info("Cross-peer match: #{local_player.player_id} (local) vs #{remote_player["player_id"]} (remote)")
        propose_match(local_player, remote_player, state)
    end
  end

  defp attempt_dht_matchmaking(state) do
    # Fallback: Find opponent from DHT
    case find_opponents_from_dht(state) do
      {:ok, opponents} when length(opponents) > 0 ->
        # Select opponent with lowest timestamp (deterministic)
        opponent = Enum.min_by(opponents, & &1["timestamp"])

        # Get our first waiting player
        case get_first_waiting_player(state) do
          nil ->
            state

          {_player_id, player_info} ->
            propose_match(player_info, opponent, state)
        end

      _ ->
        state
    end
  end

  defp get_first_waiting_player(state) do
    state.waiting_players
    |> Enum.sort_by(fn {_id, info} -> info.timestamp end)
    |> List.first()
  end

  defp get_first_remote_player(state) do
    state.remote_players
    |> Enum.sort_by(fn {_id, info} -> info["timestamp"] end)
    |> List.first()
  end

  defp try_local_matchmaking(state) do
    # Get two waiting players sorted by timestamp
    players = state.waiting_players
    |> Enum.sort_by(fn {_id, info} -> info.timestamp end)
    |> Enum.take(2)

    case players do
      [{_id1, player1}, {_id2, player2}] ->
        Logger.info("Local matchmaking: #{player1.player_id} vs #{player2.player_id}")

        match_id = generate_match_id(player1.player_id, player2.player_id)

        # Remove both players from waiting
        new_waiting = state.waiting_players
        |> Map.delete(player1.player_id)
        |> Map.delete(player2.player_id)

        # Add to in-game set
        new_players_in_game = state.players_in_game
        |> MapSet.put(player1.player_id)
        |> MapSet.put(player2.player_id)

        # Start game directly (we are always host for local matches)
        {:ok, game_pid} =
          DynamicSupervisor.start_child(
            MaculaArcade.GameSupervisor,
            {GameServer, [game_id: match_id]}
          )

        {:ok, ^match_id} = GameServer.start_game(game_pid, player1.player_id, player2.player_id)

        # Broadcast game start locally via Phoenix PubSub
        Phoenix.PubSub.broadcast(MaculaArcade.PubSub, "arcade.game.start", {
          :game_started,
          %{
            game_id: match_id,
            player1_id: player1.player_id,
            player2_id: player2.player_id
          }
        })

        Logger.info("Started local game #{match_id}: #{player1.player_id} vs #{player2.player_id}")

        # Track game
        game_info = %{
          pid: game_pid,
          players: [player1.player_id, player2.player_id],
          started_at: System.system_time(:second)
        }

        %{state |
          waiting_players: new_waiting,
          active_games: Map.put(state.active_games, match_id, game_info),
          players_in_game: new_players_in_game
        }

      _ ->
        # Not enough players
        state
    end
  end

  defp find_opponents_from_dht(state) do
    # For now, use find_opponents RPC
    # In future, query DHT directly
    client = Mesh.client()
    case :macula.call(client, @find_opponents_proc, %{
      "exclude_player_id" => nil,
      "limit" => 10
    }, %{timeout: 3000}) do
      {:ok, %{"opponents" => opponents}} ->
        # Filter out our own players and players already matched
        filtered = Enum.reject(opponents, fn opp ->
          opp["node_id"] == state.node_id or
          Map.has_key?(state.pending_matches, generate_match_id(opp["player_id"], opp["player_id"]))
        end)
        {:ok, filtered}

      {:error, reason} ->
        Logger.debug("find_opponents failed: #{inspect(reason)}")
        {:ok, []}
    end
  end

  defp propose_match(player_info, opponent, state) do
    match_id = generate_match_id(player_info.player_id, opponent["player_id"])
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    proposal = %{
      match_id: match_id,
      player1_id: player_info.player_id,
      player1_node_id: player_info.node_id,
      player2_id: opponent["player_id"],
      player2_node_id: opponent["node_id"],
      proposed_by: state.node_id,
      timestamp: timestamp
    }

    # Track pending match
    new_pending = Map.put(state.pending_matches, match_id, proposal)

    # Remove local player from waiting queue
    new_waiting = Map.delete(state.waiting_players, player_info.player_id)

    # Remove opponent from remote_players (if they were remote)
    new_remote = Map.delete(state.remote_players, opponent["player_id"])

    # Publish proposal (with hex-encoded node_ids for JSON)
    publish_event(@match_proposed_topic, %{
      proposal |
      player1_node_id: encode_node_id(player_info.node_id),
      player2_node_id: encode_node_id(opponent["node_id"]),
      proposed_by: encode_node_id(state.node_id)
    })

    Logger.info("Proposed match #{match_id}: #{player_info.player_id} vs #{opponent["player_id"]}")

    %{state |
      pending_matches: new_pending,
      waiting_players: new_waiting,
      remote_players: new_remote
    }
  end

  defp handle_match_proposal(payload, state) do
    match_id = payload["match_id"]
    player1_id = payload["player1_id"]
    player2_id = payload["player2_id"]

    # Check if one of our players is involved
    our_player_id = cond do
      Map.has_key?(state.waiting_players, player1_id) -> player1_id
      Map.has_key?(state.waiting_players, player2_id) -> player2_id
      true -> nil
    end

    case our_player_id do
      nil ->
        {:noreply, state}

      player_id ->
        # Verify match_id is correct (deterministic check)
        expected_id = generate_match_id(player1_id, player2_id)

        if match_id == expected_id do
          # Accept the match
          confirm_match(payload, player_id, state)
        else
          Logger.warning("Invalid match_id #{match_id}, expected #{expected_id}")
          {:noreply, state}
        end
    end
  end

  defp confirm_match(proposal, our_player_id, state) do
    match_id = proposal["match_id"]

    # Remove player from queue
    new_waiting = Map.delete(state.waiting_players, our_player_id)

    # Remove from DHT
    remove_player_from_dht(our_player_id)

    # Determine host (lower node_id wins)
    # Note: proposal node_ids are already hex-encoded strings from JSON
    host_node_id = determine_host(proposal["player1_node_id"], proposal["player2_node_id"])
    our_node_id_hex = encode_node_id(state.node_id)
    we_are_host = host_node_id == our_node_id_hex

    # Publish match_found (node_ids are already hex-encoded)
    match_found = %{
      match_id: match_id,
      player1_id: proposal["player1_id"],
      player1_node_id: proposal["player1_node_id"],
      player2_id: proposal["player2_id"],
      player2_node_id: proposal["player2_node_id"],
      host_node_id: host_node_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    publish_event(@match_found_topic, match_found)

    Logger.info("Match confirmed: #{match_id} (we are #{if we_are_host, do: "host", else: "guest"})")

    new_state = %{state | waiting_players: new_waiting}

    # If we're host, start the game
    if we_are_host do
      start_game_as_host(match_found, new_state)
    else
      {:noreply, new_state}
    end
  end

  defp handle_match_found(payload, state) do
    match_id = payload["match_id"]
    host_node_id = payload["host_node_id"]

    # Compare hex-encoded node IDs (payload contains hex string, state.node_id is raw binary)
    our_node_id_hex = encode_node_id(state.node_id)

    # Check if we should start game (we're host)
    if host_node_id == our_node_id_hex do
      # Check if we already started (idempotent)
      unless Map.has_key?(state.active_games, match_id) do
        start_game_as_host(payload, state)
      else
        {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  defp start_game_as_host(match_info, state) do
    match_id = match_info["match_id"] || match_info[:match_id]
    player1_id = match_info["player1_id"] || match_info[:player1_id]
    player2_id = match_info["player2_id"] || match_info[:player2_id]

    Logger.info("Starting game #{match_id} as host: #{player1_id} vs #{player2_id}")

    # Mark players as in game
    new_players_in_game =
      state.players_in_game
      |> MapSet.put(player1_id)
      |> MapSet.put(player2_id)

    # Start game server
    {:ok, game_pid} =
      DynamicSupervisor.start_child(
        MaculaArcade.GameSupervisor,
        {GameServer, [game_id: match_id]}
      )

    # Start the game
    {:ok, ^match_id} = GameServer.start_game(game_pid, player1_id, player2_id)

    # Get initial state
    initial_state = GameServer.get_state(game_pid)

    # Publish game_started event (with hex-encoded node_id for JSON)
    publish_event(@game_started_topic, %{
      match_id: match_id,
      host_node_id: encode_node_id(state.node_id),
      initial_state: initial_state,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    # Also broadcast locally via Phoenix PubSub for UI
    Phoenix.PubSub.broadcast(MaculaArcade.PubSub, "arcade.game.start", {
      :game_started,
      %{
        game_id: match_id,
        player1_id: player1_id,
        player2_id: player2_id
      }
    })

    # Track game
    game_info = %{
      pid: game_pid,
      players: [player1_id, player2_id],
      started_at: System.system_time(:second)
    }

    new_state = %{state |
      active_games: Map.put(state.active_games, match_id, game_info),
      players_in_game: new_players_in_game,
      pending_matches: Map.delete(state.pending_matches, match_id)
    }

    {:noreply, new_state}
  end

  defp handle_game_ended(payload, state) do
    match_id = payload["match_id"]

    case Map.get(state.active_games, match_id) do
      nil ->
        {:noreply, state}

      %{players: players} ->
        # Remove players from in_game set
        new_players_in_game = Enum.reduce(players, state.players_in_game, fn p, acc ->
          MapSet.delete(acc, p)
        end)

        new_state = %{state |
          active_games: Map.delete(state.active_games, match_id),
          players_in_game: new_players_in_game
        }

        Logger.info("Game #{match_id} ended: #{payload["reason"]}")

        {:noreply, new_state}
    end
  end

  ## RPC Handlers

  defp handle_register_player_rpc(args) do
    player_id = args["player_id"]
    player_name = args["player_name"] || player_id

    case register_player(player_id, player_name) do
      {:ok, result} ->
        %{"success" => true, "queue_position" => result.queue_position}

      {:error, reason} ->
        %{"success" => false, "error" => to_string(reason)}
    end
  end

  defp handle_find_opponents_rpc(args) do
    exclude_id = args["exclude_player_id"]
    limit = args["limit"] || 10

    # Return our waiting players (except excluded)
    opponents =
      __MODULE__
      |> GenServer.call(:get_queue_status)
      |> Map.get(:players, [])
      |> Enum.reject(& &1 == exclude_id)
      |> Enum.take(limit)
      |> Enum.map(fn player_id ->
        # Get full info from our state
        case GenServer.call(__MODULE__, {:get_player_info, player_id}) do
          {:ok, info} -> info
          _ -> %{"player_id" => player_id}
        end
      end)

    %{"opponents" => opponents}
  end

  defp handle_submit_action_rpc(args) do
    match_id = args["match_id"]
    player_id = args["player_id"]
    action = args["action"]

    case GenServer.call(__MODULE__, {:submit_action, match_id, player_id, action}) do
      {:ok, tick} ->
        %{"accepted" => true, "tick" => tick}

      {:error, reason} ->
        %{"accepted" => false, "error" => to_string(reason)}
    end
  end

  @impl true
  def handle_call({:get_player_info, player_id}, _from, state) do
    case Map.get(state.waiting_players, player_id) do
      nil -> {:reply, {:error, :not_found}, state}
      info -> {:reply, {:ok, Map.from_struct(info)}, state}
    end
  end

  @impl true
  def handle_call({:submit_action, match_id, player_id, action}, _from, state) do
    case Map.get(state.active_games, match_id) do
      nil ->
        {:reply, {:error, :game_not_found}, state}

      %{pid: game_pid} ->
        result = GameServer.submit_action(game_pid, player_id, action)
        {:reply, result, state}
    end
  end

  ## DHT Operations

  defp store_player_in_dht(player_info) do
    # Store player info in DHT under queue key
    # For now, this is handled by the advertise_service
    # In future, use explicit DHT STORE
    Logger.debug("Storing player #{player_info.player_id} in DHT")
    :ok
  end

  defp remove_player_from_dht(player_id) do
    Logger.debug("Removing player #{player_id} from DHT")
    :ok
  end

  ## Helper Functions

  defp generate_match_id(player1_id, player2_id) do
    # Deterministic: sort player IDs and hash
    sorted = Enum.sort([player1_id, player2_id])
    :crypto.hash(:sha256, Enum.join(sorted, ":"))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  defp determine_host(node1_id, node2_id) do
    # Deterministic: lower node_id becomes host
    if node1_id <= node2_id, do: node1_id, else: node2_id
  end

  defp publish_event(topic, payload) do
    Logger.debug("Publishing event to #{topic}")
    client = Mesh.client()
    case :macula.publish(client, topic, payload) do
      :ok ->
        Logger.debug("Published event to #{topic}")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to publish to #{topic}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp inspect_node_id(node_id) when is_binary(node_id) do
    node_id
    |> :binary.bin_to_list()
    |> Enum.take(8)
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.join()
  end

  defp inspect_node_id(node_id), do: inspect(node_id)

  # Helper to conditionally add player to in_game set if they were in our waiting list
  defp maybe_add_player(players_in_game, player_id, waiting_players) do
    if Map.has_key?(waiting_players, player_id) do
      MapSet.put(players_in_game, player_id)
    else
      players_in_game
    end
  end

  # Encode binary node_id to hex string for JSON serialization
  # Idempotent - if already hex-encoded, returns unchanged
  defp encode_node_id(node_id) when is_binary(node_id) do
    # Check if already hex-encoded (64 hex chars vs 32 raw bytes)
    # Raw binary has non-printable chars, hex string only has 0-9a-f
    if byte_size(node_id) == 32 do
      # Likely raw binary - encode it
      Base.encode16(node_id, case: :lower)
    else
      # Already encoded or different format - return as-is
      node_id
    end
  end

  defp encode_node_id(node_id), do: node_id
end
