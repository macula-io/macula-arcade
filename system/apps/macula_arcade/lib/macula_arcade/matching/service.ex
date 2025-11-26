defmodule MaculaArcade.Matching.Service do
  @moduledoc """
  Matchmaking Service - handles player queue and match creation.

  Responsibilities:
  - Register/unregister players for matchmaking
  - Track local and remote players via DHT pub/sub
  - Propose matches when compatible players found
  - Delegate game creation to Gaming.Supervisor

  This is the ONLY module responsible for matchmaking.
  GameCoordinator only exists after a match is made.
  """

  use GenServer
  require Logger
  alias MaculaArcade.Mesh

  # Event topics (past tense - things that happened)
  @player_registered_topic "arcade.snake.player_registered"
  @player_unregistered_topic "arcade.snake.player_unregistered"
  @match_proposed_topic "arcade.snake.match_proposed"
  @match_confirmed_topic "arcade.snake.match_confirmed"

  defmodule State do
    @moduledoc false
    defstruct [
      :node_id,
      :subscriptions,
      waiting_players: %{},     # player_id => %{timestamp, player_name, node_id}
      remote_players: %{},      # player_id => %{timestamp, player_name, node_id}
      pending_matches: %{},     # match_id => %{player1, player2, timestamp, status}
      players_in_game: MapSet.new()
    ]
  end

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register player for matchmaking.
  Called when player clicks "Find Game".
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
  Mark a player as in-game (called by Gaming.Supervisor when game starts).
  """
  def player_joined_game(player_id) do
    GenServer.cast(__MODULE__, {:player_joined_game, player_id})
  end

  @doc """
  Mark a player as available (called when game ends).
  """
  def player_left_game(player_id) do
    GenServer.cast(__MODULE__, {:player_left_game, player_id})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Matchmaking Service starting")

    # Schedule initialization after mesh connects
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
  def handle_info({:mesh_event, topic, payload}, state) do
    handle_mesh_event(topic, payload, state)
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Call Handlers

  @impl true
  def handle_call({:register_player, player_id, player_name}, _from, state) do
    cond do
      MapSet.member?(state.players_in_game, player_id) ->
        {:reply, {:error, :in_game}, state}

      Map.has_key?(state.waiting_players, player_id) ->
        {:reply, {:error, :already_registered}, state}

      true ->
        timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

        player_info = %{
          player_id: player_id,
          player_name: player_name,
          node_id: state.node_id,
          timestamp: timestamp
        }

        new_waiting = Map.put(state.waiting_players, player_id, player_info)

        # Publish player_registered event
        publish_player_registered(player_info, state.node_id)

        Logger.info("Player #{player_id} joining queue")

        new_state = %{state | waiting_players: new_waiting}
        queue_position = map_size(new_waiting)

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

        # Publish player_unregistered event
        publish_player_unregistered(player_id, state.node_id)

        Logger.info("Player #{player_id} left queue")

        {:reply, :ok, %{state | waiting_players: new_waiting}}
    end
  end

  @impl true
  def handle_call(:get_queue_status, _from, state) do
    status = %{
      queue_size: map_size(state.waiting_players),
      players: Map.keys(state.waiting_players),
      remote_players: map_size(state.remote_players),
      pending_matches: map_size(state.pending_matches)
    }
    {:reply, status, state}
  end

  ## Cast Handlers

  @impl true
  def handle_cast({:player_joined_game, player_id}, state) do
    new_waiting = Map.delete(state.waiting_players, player_id)
    new_remote = Map.delete(state.remote_players, player_id)
    new_in_game = MapSet.put(state.players_in_game, player_id)

    {:noreply, %{state |
      waiting_players: new_waiting,
      remote_players: new_remote,
      players_in_game: new_in_game
    }}
  end

  @impl true
  def handle_cast({:player_left_game, player_id}, state) do
    new_in_game = MapSet.delete(state.players_in_game, player_id)
    {:noreply, %{state | players_in_game: new_in_game}}
  end

  ## Event Handlers

  defp handle_mesh_event(@player_registered_topic, event, state) do
    player_id = event["player_id"]
    their_node_id = event["node_id"]
    our_node_id_hex = encode_node_id(state.node_id)

    Logger.info("Received player_registered: #{player_id} from node #{their_node_id}")

    # Skip if this is our own event echoed back
    is_our_event = their_node_id == our_node_id_hex

    new_state = if is_our_event do
      # Our own event - don't add to remote_players
      state
    else
      # Remote player - add to remote_players
      new_remote = Map.put(state.remote_players, player_id, event)
      %{state | remote_players: new_remote}
    end

    # Attempt matchmaking with updated state
    new_state = attempt_matchmaking(new_state)

    {:noreply, new_state}
  end

  defp handle_mesh_event(@player_unregistered_topic, event, state) do
    player_id = event["player_id"]
    their_node_id = event["node_id"]
    our_node_id_hex = encode_node_id(state.node_id)

    if their_node_id != our_node_id_hex do
      new_remote = Map.delete(state.remote_players, player_id)
      Logger.info("Remote player #{player_id} left queue")
      {:noreply, %{state | remote_players: new_remote}}
    else
      {:noreply, state}
    end
  end

  defp handle_mesh_event(@match_proposed_topic, event, state) do
    handle_match_proposal(event, state)
  end

  defp handle_mesh_event(@match_confirmed_topic, event, state) do
    handle_match_confirmed(event, state)
  end

  defp handle_mesh_event(_topic, _event, state) do
    {:noreply, state}
  end

  ## Matchmaking Logic

  defp attempt_matchmaking(state) do
    case {get_first_waiting_player(state), get_first_remote_player(state)} do
      {nil, _} ->
        # No local players waiting
        state

      {_, nil} ->
        # No remote players available
        state

      {{local_id, local_player}, {remote_id, remote_player}} ->
        # Don't match player with themselves
        if local_id == remote_id do
          state
        else
          Logger.info("Match found: #{local_id} (local) vs #{remote_id} (remote)")
          propose_match(local_player, remote_player, state)
        end
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

  defp propose_match(local_player, remote_player, state) do
    match_id = generate_match_id(local_player.player_id, remote_player["player_id"])
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    proposal = %{
      match_id: match_id,
      player1_id: local_player.player_id,
      player1_node_id: encode_node_id(local_player.node_id),
      player2_id: remote_player["player_id"],
      player2_node_id: remote_player["node_id"],
      proposed_by: encode_node_id(state.node_id),
      timestamp: timestamp
    }

    # Track pending match
    new_pending = Map.put(state.pending_matches, match_id, %{
      proposal: proposal,
      status: :proposed,
      confirmations: MapSet.new([encode_node_id(state.node_id)])
    })

    # Remove players from queues
    new_waiting = Map.delete(state.waiting_players, local_player.player_id)
    new_remote = Map.delete(state.remote_players, remote_player["player_id"])

    # Publish proposal
    publish_match_proposed(proposal)

    Logger.info("Proposed match #{match_id}: #{local_player.player_id} vs #{remote_player["player_id"]}")

    %{state |
      pending_matches: new_pending,
      waiting_players: new_waiting,
      remote_players: new_remote
    }
  end

  defp handle_match_proposal(proposal, state) do
    match_id = proposal["match_id"]
    player1_id = proposal["player1_id"]
    player2_id = proposal["player2_id"]
    our_node_id_hex = encode_node_id(state.node_id)

    # First check if we already proposed this match (we're the proposer)
    # This handles the race condition where both peers propose simultaneously
    case Map.get(state.pending_matches, match_id) do
      %{confirmations: confirmations} = pending_match ->
        # We already have this match pending - this is the other peer's proposal
        # arriving after we proposed. Treat it as a confirmation from them.
        proposer_node = proposal["proposed_by"]
        Logger.info("Received match proposal #{match_id} from #{proposer_node} (we already proposed)")

        new_confirmations = MapSet.put(confirmations, proposer_node)
        new_pending_match = %{pending_match | confirmations: new_confirmations}
        new_pending = Map.put(state.pending_matches, match_id, new_pending_match)
        new_state = %{state | pending_matches: new_pending}

        # Check if both sides confirmed
        if MapSet.size(new_confirmations) >= 2 do
          Logger.info("Match #{match_id} confirmed by both sides (via proposals)")
          start_game_from_match(pending_match.proposal, new_state)
        else
          {:noreply, new_state}
        end

      nil ->
        # We don't have this match pending - check if one of our players is involved
        our_player = cond do
          Map.has_key?(state.waiting_players, player1_id) -> player1_id
          Map.has_key?(state.waiting_players, player2_id) -> player2_id
          true -> nil
        end

        case our_player do
          nil ->
            {:noreply, state}

          player_id ->
            # Verify match_id is correct
            expected_id = generate_match_id(player1_id, player2_id)

            if match_id == expected_id do
              Logger.info("Confirming match #{match_id} for player #{player_id}")

              # Remove our player from queue
              new_waiting = Map.delete(state.waiting_players, player_id)

              # Track/update pending match
              pending_match = %{
                proposal: proposal,
                status: :proposed,
                confirmations: MapSet.new()
              }

              new_confirmations = MapSet.put(pending_match.confirmations, our_node_id_hex)

              new_pending_match = %{pending_match |
                confirmations: new_confirmations
              }

              new_pending = Map.put(state.pending_matches, match_id, new_pending_match)

              # Publish confirmation
              publish_match_confirmed(match_id, our_node_id_hex)

              new_state = %{state |
                waiting_players: new_waiting,
                pending_matches: new_pending
              }

              # Check if both sides confirmed
              if MapSet.size(new_confirmations) >= 2 do
                start_game_from_match(proposal, new_state)
              else
                {:noreply, new_state}
              end
            else
              {:noreply, state}
            end
        end
    end
  end

  defp handle_match_confirmed(event, state) do
    match_id = event["match_id"]
    confirming_node = event["node_id"]

    case Map.get(state.pending_matches, match_id) do
      nil ->
        {:noreply, state}

      pending_match ->
        new_confirmations = MapSet.put(pending_match.confirmations, confirming_node)

        new_pending_match = %{pending_match | confirmations: new_confirmations}
        new_pending = Map.put(state.pending_matches, match_id, new_pending_match)

        new_state = %{state | pending_matches: new_pending}

        # Check if both sides confirmed
        if MapSet.size(new_confirmations) >= 2 do
          start_game_from_match(pending_match.proposal, new_state)
        else
          {:noreply, new_state}
        end
    end
  end

  defp start_game_from_match(proposal, state) do
    match_id = proposal["match_id"] || proposal[:match_id]
    player1_id = proposal["player1_id"] || proposal[:player1_id]
    player2_id = proposal["player2_id"] || proposal[:player2_id]
    player1_node_id = proposal["player1_node_id"] || proposal[:player1_node_id]
    player2_node_id = proposal["player2_node_id"] || proposal[:player2_node_id]

    # Determine host (lower node_id wins)
    host_node_id = if player1_node_id <= player2_node_id, do: player1_node_id, else: player2_node_id
    our_node_id_hex = encode_node_id(state.node_id)
    we_are_host = host_node_id == our_node_id_hex

    Logger.info("Match #{match_id} ready. Host: #{host_node_id}, We are host: #{we_are_host}")

    if we_are_host do
      # Start game via Gaming.Supervisor
      case MaculaArcade.Gaming.Supervisor.start_game(match_id, player1_id, player2_id) do
        {:ok, _game_pid} ->
          Logger.info("Game #{match_id} started successfully")

          # Mark players as in-game
          new_in_game = state.players_in_game
          |> MapSet.put(player1_id)
          |> MapSet.put(player2_id)

          # Remove from pending
          new_pending = Map.delete(state.pending_matches, match_id)

          {:noreply, %{state |
            players_in_game: new_in_game,
            pending_matches: new_pending
          }}

        {:error, reason} ->
          Logger.error("Failed to start game #{match_id}: #{inspect(reason)}")
          {:noreply, state}
      end
    else
      # We're guest - game will be started by host
      # Just mark players as in-game when we receive game_started event
      new_pending = Map.delete(state.pending_matches, match_id)
      {:noreply, %{state | pending_matches: new_pending}}
    end
  end

  ## Mesh Helpers

  defp initialize_mesh_connection(state) do
    with {:ok, node_id} <- get_node_id(),
         {:ok, subs} <- subscribe_to_events() do

      Logger.info("Matchmaking Service initialized on node #{encode_node_id(node_id)}")

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
    coordinator_pid = self()
    client = Mesh.client()

    events = [
      @player_registered_topic,
      @player_unregistered_topic,
      @match_proposed_topic,
      @match_confirmed_topic
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

  ## Publishing Helpers

  defp publish_player_registered(player_info, node_id) do
    event_payload = Map.put(player_info, :node_id, encode_node_id(node_id))
    Task.start(fn -> publish_event(@player_registered_topic, event_payload) end)
  end

  defp publish_player_unregistered(player_id, node_id) do
    Task.start(fn ->
      publish_event(@player_unregistered_topic, %{
        player_id: player_id,
        node_id: encode_node_id(node_id),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        reason: "cancelled"
      })
    end)
  end

  defp publish_match_proposed(proposal) do
    Task.start(fn -> publish_event(@match_proposed_topic, proposal) end)
  end

  defp publish_match_confirmed(match_id, node_id) do
    Task.start(fn ->
      publish_event(@match_confirmed_topic, %{
        match_id: match_id,
        node_id: node_id,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end)
  end

  defp publish_event(topic, payload) do
    Logger.info("[MatchmakingService] Publishing to #{topic}: #{inspect(Map.keys(payload))}")
    client = Mesh.client()
    Logger.debug("[MatchmakingService] Got client PID: #{inspect(client)}")
    result = :macula.publish(client, topic, payload)
    Logger.info("[MatchmakingService] Publish result: #{inspect(result)}")
    case result do
      :ok -> :ok
      {:error, reason} ->
        Logger.warning("Failed to publish to #{topic}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## Utility Helpers

  defp generate_match_id(player1_id, player2_id) do
    sorted = Enum.sort([player1_id, player2_id])
    :crypto.hash(:sha256, Enum.join(sorted, ":"))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
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
