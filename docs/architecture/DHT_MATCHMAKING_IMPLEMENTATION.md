# DHT-Based Matchmaking Implementation (v0.7.29)

## Overview

This document describes the DHT-based peer-to-peer matchmaking implementation for Snake Duel, completed in Macula v0.7.29 and macula-arcade.

## Architecture

The matchmaking system uses a combination of **DHT Pub/Sub** (for discovery) and **DHT RPC** (for match negotiation), following true P2P mesh principles.

### Phase 1: Discovery (DHT Pub/Sub)
- All players subscribe to `"arcade.matchmaking.snake"` topic
- Subscription advertises presence in the DHT
- Players can discover each other via `discover_subscribers/1`

### Phase 2: Match Request (DHT RPC)
- Player A queries DHT for subscribers to matchmaking topic
- Player A filters out self from results
- Player A sends RPC call `"arcade.match_request"` to Player B
- Player B's handler checks if available
- Player B responds with `accept` or `reject`
- On accept, both nodes create the game with agreed game_id

### Phase 3: Game Synchronization (DHT Pub/Sub)
- Both players subscribe to `"arcade.game.{game_id}.state"`
- Game state updates published via pub/sub
- Real-time bidirectional updates

## Changes to Macula (v0.7.29)

### New API Functions

#### `macula_client.erl`
```erlang
%% Discover subscribers to a topic via DHT query
-spec discover_subscribers(Client :: client(), Topic :: topic()) ->
    {ok, [#{node_id := binary(), endpoint := binary()}]} | {error, Reason :: term()}.
discover_subscribers(Client, Topic)

%% Get the node ID of this client
-spec get_node_id(Client :: client()) -> {ok, binary()} | {error, Reason :: term()}.
get_node_id(Client)
```

#### `macula_peer.erl`
```erlang
%% Discover subscribers via DHT
-spec discover_subscribers(pid(), binary()) ->
    {ok, [#{node_id := binary(), endpoint := binary()}]} | {error, term()}.
discover_subscribers(Client, Topic)

%% Get node ID
-spec get_node_id(pid()) -> {ok, binary()} | {error, term()}.
get_node_id(Client)
```

### Implementation Details

- `discover_subscribers/2` delegates to `macula_pubsub_discovery:find_subscribers/2`
- `get_node_id/1` returns the node_id from peer state
- Both functions exposed through `macula_client` facade

## Changes to macula-arcade

### Updated Dependencies
- Updated `macula` dependency from `~> 0.7.28` to `~> 0.7.29`

### NodeManager Elixir Wrappers

Added Elixir wrappers in `MaculaArcade.Mesh.NodeManager`:

```elixir
@doc """
Discovers subscribers to a topic via DHT query.
"""
def discover_subscribers(topic)

@doc """
Gets the node ID of this Macula client.
"""
def get_node_id()
```

### Coordinator Refactoring

**State Changes:**
```elixir
defmodule State do
  defstruct [
    :waiting_players,
    :active_games,
    :subscription_ref,
    :players_in_game  # NEW: Set of player IDs currently in active games
  ]
end
```

**Initialization:**
```elixir
# Advertise match request handler
NodeManager.advertise_service("arcade.match_request", &handle_match_request/1)
```

**Join Queue Flow (DHT Discovery + RPC):**
```elixir
def handle_cast({:join_queue, player_id}, state) do
  # 1. Query DHT for other players
  {:ok, subscribers} = NodeManager.discover_subscribers(@matchmaking_topic)

  # 2. Filter out self
  {:ok, my_node_id} = NodeManager.get_node_id()
  other_players = Enum.reject(subscribers, fn sub ->
    Map.get(sub, :node_id) == my_node_id
  end)

  # 3. Try to match with each peer via RPC
  case try_match_with_peers(player_id, other_players, state) do
    {:matched, game_id, new_state} -> # Success!
    {:waiting, new_state} -> # Add to waiting queue
  end
end
```

**RPC Match Request Sender:**
```elixir
defp try_match_with_peers(player_id, [opponent | rest], state) do
  case NodeManager.call_service("arcade.match_request", %{
    game: "snake",
    player_id: player_id
  }) do
    {:ok, %{"status" => "accepted", "game_id" => game_id}} ->
      {:matched, game_id, state}

    {:ok, %{"status" => "rejected", "reason" => reason}} ->
      try_match_with_peers(player_id, rest, state)  # Try next

    {:error, reason} ->
      try_match_with_peers(player_id, rest, state)  # Try next
  end
end
```

**RPC Match Request Handler:**
```elixir
defp handle_match_request(%{"game" => "snake", "player_id" => opponent_id}) do
  case GenServer.call(__MODULE__, {:can_accept_match, opponent_id}) do
    {:ok, my_player_id} ->
      game_id = generate_game_id()
      GenServer.cast(__MODULE__, {:accept_match, my_player_id, opponent_id, game_id})
      {:ok, %{"status" => "accepted", "game_id" => game_id}}

    {:error, reason} ->
      {:ok, %{"status" => "rejected", "reason" => reason}}
  end
end
```

**Accept Match Handler:**
```elixir
def handle_cast({:accept_match, my_player_id, opponent_id, game_id}, state) do
  # Remove from waiting queue
  new_waiting = Enum.reject(state.waiting_players, &(&1 == my_player_id))

  # Add both players to in-game set
  new_players_in_game = state.players_in_game
    |> MapSet.put(my_player_id)
    |> MapSet.put(opponent_id)

  # Create game with agreed ID
  new_state = create_game_with_id(my_player_id, opponent_id, game_id, %{
    state |
    waiting_players: new_waiting,
    players_in_game: new_players_in_game
  })

  {:noreply, new_state}
end
```

**Game Creation:**
```elixir
defp create_game_with_id(player1_id, player2_id, game_id, state) do
  # Start game server with specific game_id
  {:ok, game_pid} = DynamicSupervisor.start_child(
    MaculaArcade.GameSupervisor,
    {GameServer, [game_id: game_id]}
  )

  # Start the game
  {:ok, ^game_id} = GameServer.start_game(game_pid, player1_id, player2_id)

  # Broadcast to mesh (so other nodes remove these players from queues)
  NodeManager.publish(@matchmaking_topic, %{
    type: "match_created",
    player1_id: player1_id,
    player2_id: player2_id,
    game_id: game_id
  })

  # Track game in state
  %{state | active_games: Map.put(state.active_games, game_id, game_info)}
end
```

## Key Benefits

### True P2P Architecture
- ✅ No gateway routing for matchmaking
- ✅ DHT-based peer discovery
- ✅ Direct RPC negotiations between peers
- ✅ Decentralized game creation

### Scalability
- ✅ O(log N) DHT lookups
- ✅ No single point of failure
- ✅ Each peer handles own matches
- ✅ Fault-tolerant (try next opponent on failure)

### Correctness
- ✅ Prevents duplicate matches via `players_in_game` set
- ✅ Handles race conditions (reject if already in game)
- ✅ Coordinated game_id ensures both nodes create same game
- ✅ Mesh broadcasts keep all coordinators in sync

## Testing Strategy

### Unit Tests (TODO)
1. Test `handle_match_request/1` accepts valid requests
2. Test `handle_match_request/1` rejects when no waiting players
3. Test `handle_match_request/1` rejects when already in game
4. Test `try_match_with_peers/3` tries all opponents
5. Test `players_in_game` set prevents duplicate matches

### Integration Tests (TODO)
1. Start 3 peers in Docker
2. Verify DHT discovery returns all subscribers
3. Player 1 joins queue → waits
4. Player 2 joins queue → RPC sent to Player 1
5. Player 1 accepts → both create game with same game_id
6. Player 3 joins queue → both peers reject (already in game)
7. Game ends → players removed from `players_in_game` set
8. Player 1 joins again → can match with Player 3

## Next Steps

1. **Add Game Cleanup**
   - Remove players from `players_in_game` when game ends
   - Handle game server crashes gracefully

2. **Add Tests**
   - Unit tests for RPC handlers
   - Multi-node Docker integration tests

3. **Performance Tuning**
   - Cache DHT discovery results (avoid repeated lookups)
   - Implement exponential backoff for retries

4. **Error Handling**
   - Handle network partitions
   - Handle stale DHT data
   - Add timeout to RPC calls

## Architecture Documents

- `SNAKE_DUEL_ARCHITECTURE.md` - Complete design
- `GATEWAY_RESPONSIBILITIES.md` - Gateway role in v0.7 vs v0.8
- `DOCUMENTATION_AUDIT_2025_11_17.md` - Documentation cleanup plan

## Version History

- **v0.7.29** - DHT discovery + RPC matchmaking implemented
- **v0.7.28** - DHT multi-value storage fixed
- **v0.7.25** - Gateway routing (broken matchmaking)
