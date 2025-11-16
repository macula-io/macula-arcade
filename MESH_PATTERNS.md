# Macula Arcade - Distributed Mesh Patterns

## Overview

This document captures the architectural patterns used in Macula Arcade to implement true peer-to-peer mesh coordination using Macula v0.7.1's HTTP/3 mesh platform.

## Core Principle: Gateway as Bootstrap Only

**The gateway should function purely as a bootstrapping service for the mesh.**

Once the mesh is established, peers communicate directly via DHT pub/sub and RPC. In theory, you should be able to kill the gateway after peers have discovered each other, and the game should continue to function.

## Pattern 1: Distributed Queue via Mesh Pub/Sub

### Problem
Traditional matchmaking uses a centralized queue on a single server. This creates:
- Single point of failure
- Scalability bottleneck
- Violates P2P mesh principles

### Solution: Distributed Queue Pattern

Each peer maintains a **local copy** of the matchmaking queue and synchronizes via mesh pub/sub events.

**Implementation** (see `coordinator.ex`):

```elixir
# 1. Subscribe to matchmaking topic on mesh
@matchmaking_topic "arcade.matchmaking.snake"

def init(_opts) do
  case NodeManager.subscribe(@matchmaking_topic, fn event_data ->
         handle_matchmaking_event(event_data)
         :ok
       end) do
    {:ok, sub_ref} ->
      # Successfully subscribed to mesh
    {:error, :not_connected} ->
      # Retry after connection established
  end
end

# 2. Publish local join events to mesh
def handle_cast({:join_queue, player_id}, state) do
  # Add to local queue
  new_waiting = [player_id | state.waiting_players] |> Enum.uniq()

  # Publish to mesh so ALL coordinators know
  NodeManager.publish(@matchmaking_topic, %{
    type: "player_joined",
    player_id: player_id,
    queue_size: length(new_waiting)
  })

  # Attempt local matching
  {matched_players, remaining_players} = match_players(new_waiting)
  # ... create games for matches
end

# 3. Process mesh events from other peers
defp handle_matchmaking_event(%{"type" => "player_joined", "player_id" => player_id}) do
  # Forward to local coordinator to add to queue
  GenServer.cast(__MODULE__, {:mesh_player_joined, player_id})
end

# 4. Handle mesh join events (from ANY peer)
def handle_cast({:mesh_player_joined, player_id}, state) do
  # Add player from ANY peer to local queue
  new_waiting = [player_id | state.waiting_players] |> Enum.uniq()

  # Attempt matching (ANY coordinator can create a match)
  {matched_players, remaining_players} = match_players(new_waiting)

  # Create games for matched players
  Enum.reduce(matched_players, state, fn {p1, p2}, acc ->
    create_game(p1, p2, acc)
  end)
end
```

### Key Characteristics

1. **Eventual Consistency**: All coordinators eventually have the same queue state
2. **Any Node Can Match**: First coordinator to see 2+ players creates the match
3. **Match Coordination**: When a match is created, publish `match_created` event so other coordinators remove those players
4. **No Central Authority**: No single coordinator is "in charge"

## Pattern 2: Match Coordination to Prevent Duplicates

### Problem
If multiple coordinators see 2+ players in the queue simultaneously, they might all try to create matches for the same players.

### Solution: Match Creation Broadcast

When a coordinator creates a match, it immediately broadcasts a `match_created` event so other coordinators remove those players from their queues.

**Implementation**:

```elixir
defp create_game(player1_id, player2_id, state) do
  # Start game server
  {:ok, game_pid} = DynamicSupervisor.start_child(...)
  {:ok, game_id} = GameServer.start_game(game_pid, player1_id, player2_id)

  # IMMEDIATELY broadcast match creation to mesh
  NodeManager.publish(@matchmaking_topic, %{
    type: "match_created",
    player1_id: player1_id,
    player2_id: player2_id,
    game_id: game_id
  })

  # Also broadcast game start event
  NodeManager.publish(@game_start_topic, %{
    type: "game_started",
    game_id: game_id,
    player1_id: player1_id,
    player2_id: player2_id
  })
end

# Other coordinators handle match_created events
defp handle_matchmaking_event(%{"type" => "match_created", "player1_id" => p1, "player2_id" => p2}) do
  GenServer.cast(__MODULE__, {:mesh_match_created, p1, p2})
end

def handle_cast({:mesh_match_created, player1_id, player2_id}, state) do
  # Remove matched players from local queue
  new_waiting = Enum.reject(state.waiting_players, &(&1 in [player1_id, player2_id]))
  {:noreply, %{state | waiting_players: new_waiting}}
end
```

### Race Condition Handling

In rare cases, two coordinators might create matches simultaneously. This is acceptable because:
1. Each player has a unique ID
2. The first `game_started` event that reaches a client will be accepted
3. The client only responds to games where they are a participant
4. Extra game servers will timeout and be cleaned up

## Pattern 3: Dual Pub/Sub (Mesh + Local)

### Problem
Need to support both single-container (development) and multi-container (production) deployments.

### Solution: Dual Broadcast Pattern

Publish events to BOTH Macula mesh (for cross-container) AND Phoenix PubSub (for same-container).

**Implementation**:

```elixir
# In GameServer.broadcast_state/1
defp broadcast_state(state) do
  game_topic = "arcade.game.#{state.game_id}.state"
  state_data = serialize_state(state)

  # 1. Broadcast via Macula mesh (for multi-container)
  try do
    NodeManager.publish(game_topic, state_data)
  catch
    :exit, reason ->
      Logger.warning("Failed to publish via mesh: #{inspect(reason)}")
  end

  # 2. ALSO broadcast locally via Phoenix PubSub (for single-container)
  Phoenix.PubSub.broadcast(MaculaArcade.PubSub, game_topic, {:game_state_update, state_data})
end

# In SnakeLive.mount/3
def mount(_params, _session, socket) do
  # Subscribe to BOTH pub/sub systems

  # 1. Phoenix PubSub (local, always works)
  Phoenix.PubSub.subscribe(MaculaArcade.PubSub, "arcade.game.start")

  # 2. Macula mesh (cross-container, may not be available)
  case NodeManager.subscribe("arcade.game.start", fn event_data ->
         send(self(), {:game_started, event_data})
         :ok
       end) do
    {:ok, _sub_ref} ->
      Logger.info("Subscribed to mesh successfully")
    {:error, reason} ->
      Logger.warn("Mesh not available: #{inspect(reason)}")
  end

  {:ok, socket}
end
```

### Benefits

1. **Development Simplicity**: Single-container setup works with Phoenix PubSub
2. **Production Scale**: Multi-container setup uses mesh for cross-container communication
3. **Graceful Degradation**: If mesh is unavailable, local pub/sub still works
4. **Migration Path**: Can gradually move from local to mesh-based architecture

## Pattern 4: Resilient Mesh Subscription

### Problem
NodeManager might not be connected to the mesh when a GenServer initializes (especially during startup).

### Solution: Retry Pattern with Delayed Initialization

**Implementation**:

```elixir
def init(_opts) do
  case NodeManager.subscribe(@matchmaking_topic, fn event_data ->
         handle_matchmaking_event(event_data)
         :ok
       end) do
    {:ok, sub_ref} ->
      # Success - mesh is connected
      state = %State{
        waiting_players: [],
        active_games: %{},
        subscription_ref: sub_ref
      }
      {:ok, state}

    {:error, :not_connected} ->
      # Mesh not ready - retry after 1 second
      Logger.info("Mesh not connected yet, will retry subscription in 1 second")
      Process.send_after(self(), :retry_subscribe, 1000)

      state = %State{
        waiting_players: [],
        active_games: %{},
        subscription_ref: nil
      }
      {:ok, state}
  end
end

def handle_info(:retry_subscribe, state) do
  case NodeManager.subscribe(@matchmaking_topic, fn event_data ->
         handle_matchmaking_event(event_data)
         :ok
       end) do
    {:ok, sub_ref} ->
      Logger.info("Successfully subscribed to mesh after retry")
      {:noreply, %{state | subscription_ref: sub_ref}}

    {:error, :not_connected} ->
      # Still not ready - keep retrying
      Process.send_after(self(), :retry_subscribe, 1000)
      {:noreply, state}
  end
end
```

### Benefits

1. **Startup Resilience**: GenServer doesn't crash if mesh isn't ready
2. **Eventual Connection**: Automatically subscribes when mesh becomes available
3. **No Message Loss**: Queue operations work locally even before mesh connection

## Pattern 5: Docker Service Name Resolution

### Problem
In Docker Compose, containers need to connect to the gateway, but `localhost` refers to the container itself, not the gateway.

### Solution: Environment Variable with Service Name Default

**Implementation**:

```elixir
# In NodeManager
defp mesh_url do
  System.get_env("MACULA_GATEWAY_URL", "https://arcade-gateway:4433")
end

def init(_opts) do
  gateway_url = mesh_url()  # Use Docker service name
  Logger.info("Connecting to mesh at #{gateway_url}")

  connect_opts = %{realm: @realm, timeout: 10_000}

  case :macula_client.connect(gateway_url, connect_opts) do
    {:ok, client} -> {:ok, %{client: client}}
    {:error, reason} -> {:stop, {:connection_failed, reason}}
  end
end
```

**Docker Compose Configuration**:

```yaml
services:
  gateway:
    container_name: arcade-gateway
    # ... gateway config

  peer1:
    environment:
      - MACULA_GATEWAY_URL=https://arcade-gateway:4433
    depends_on:
      gateway:
        condition: service_healthy
```

### Key Points

1. Use **Docker service names** (`arcade-gateway`) not `localhost`
2. Docker DNS automatically resolves service names to container IPs
3. Environment variable allows override for different environments
4. `depends_on` with health check ensures gateway is ready before peers connect

## Pattern 6: Crash-Resistant Publishing

### Problem
If NodeManager crashes or is shutting down during a publish, the publishing GenServer can crash too, causing cascading failures.

### Solution: Try/Catch Around Mesh Operations

**Implementation**:

```elixir
defp broadcast_state(state) do
  game_topic = "arcade.game.#{state.game_id}.state"
  state_data = serialize_state(state)

  # Wrap mesh publish in try/catch to prevent crashes
  try do
    NodeManager.publish(game_topic, state_data)
  catch
    :exit, reason ->
      Logger.warning("Failed to publish game state via mesh: #{inspect(reason)}")
  end

  # Always broadcast locally (more reliable)
  Phoenix.PubSub.broadcast(MaculaArcade.PubSub, game_topic, {:game_state_update, state_data})
end
```

### Benefits

1. **Fault Isolation**: Mesh failures don't crash game servers
2. **Graceful Degradation**: Local pub/sub continues working
3. **Observability**: Warnings logged for debugging
4. **Resilience**: System continues functioning during mesh issues

## Testing the Mesh Architecture

### Single Container Test
```bash
# Start single container
docker-compose up

# Open multiple browsers to http://localhost:4000
# Players should match within same container via Phoenix PubSub
```

### Multi-Container Test
```bash
# Start mesh test environment
docker-compose -f docker-compose.mesh-test.yml up

# Open browsers to different peers:
# - http://localhost:4001 (peer1)
# - http://localhost:4002 (peer2)
# - http://localhost:4003 (peer3)

# Players on different containers should match via Macula mesh
```

### Verify Mesh Communication
```bash
# Check coordinator logs for mesh events
docker logs arcade-peer1 2>&1 | grep -E "(Matchmaking event|Player.*joining)"

# Should see:
# - "Player X joining queue" (local join)
# - "Matchmaking event received from mesh: player Y joined" (remote join)
# - "Creating game for X vs Y" (match created)
```

### Gateway Independence Test
```bash
# Start mesh and let players connect
docker-compose -f docker-compose.mesh-test.yml up -d

# Wait for players to match
sleep 10

# Kill gateway (mesh should continue)
docker stop arcade-gateway

# Verify games continue (pub/sub should still work via established peer connections)
# Note: New matchmaking won't work without gateway, but active games should continue
```

## Future Improvements

### 1. True Gateway-Less Operation
Implement full Kademlia DHT routing so peers can discover each other without gateway:
- Peer-to-peer connection establishment
- DHT-based service discovery
- Gateway only needed for initial bootstrap

### 2. Leader Election for Match Creation
Use Raft consensus or distributed lock to ensure only one coordinator creates each match:
- Eliminates rare race conditions
- More deterministic matching
- Higher complexity

### 3. Queue Persistence
Persist matchmaking queue to handle coordinator crashes:
- Players don't lose queue position
- Graceful recovery
- Requires distributed storage (DHT or shared database)

### 4. Cross-Realm Matchmaking
Support matchmaking across different realms:
- Regional matchmaking
- Skill-based matchmaking
- Topic-based routing

## References

- Macula v0.7.1 documentation: `/home/rl/work/github.com/macula-io/macula/CLAUDE.md`
- Distributed systems patterns: CAP theorem, eventual consistency
- Kademlia DHT: XOR-distance routing
- OTP supervision: fault tolerance patterns

## Version History

- 2025-11-15: Initial documentation of distributed mesh patterns
- Implemented in Macula Arcade v0.1.0 with Macula v0.7.1
