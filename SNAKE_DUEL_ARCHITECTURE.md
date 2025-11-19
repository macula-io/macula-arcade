# Snake Duel Architecture - DHT RPC + DHT Pub/Sub

## Overview

Snake Duel demonstrates **correct usage** of Macula's DHT-routed messaging:
- **DHT Pub/Sub** for discovery and broadcast (matchmaking, game state)
- **DHT RPC** for point-to-point requests (match negotiation)

## Architecture Phases

### Phase 1: Discovery (DHT Pub/Sub)

**Goal**: Players advertise availability and discover each other

**Flow**:
```
Player 1 (peer1)                    DHT                    Player 2 (peer2)
     |                               |                          |
     |-- SUBSCRIBE -----------------→|                          |
     |   topic: "arcade.matchmaking.snake"                     |
     |   Stores: peer1_node_id      |                          |
     |                               |←-- SUBSCRIBE ------------|
     |                               |   topic: "arcade.matchmaking.snake"
     |                               |   Stores: peer2_node_id  |
```

**Implementation**:
```elixir
# In MaculaArcade.Games.Coordinator

def init(_opts) do
  # Subscribe to matchmaking topic (advertises availability)
  {:ok, _sub_ref} = NodeManager.subscribe(
    "arcade.matchmaking.snake",
    fn event -> handle_matchmaking_event(event) end
  )

  {:ok, %State{waiting_players: [], active_games: %{}}}
end
```

**DHT Storage**:
```erlang
Key = crypto:hash(sha256, "arcade.matchmaking.snake")
Value = #{
  node_id => Peer1NodeId,
  endpoint => Peer1Endpoint,
  ttl => 300
}
```

---

### Phase 2: Match Request (DHT RPC)

**Goal**: Player initiates match with specific opponent

**Flow**:
```
Player 1                            DHT                     Player 2
     |                               |                          |
     |-- FIND_VALUE ----------------→|                          |
     |   key: hash("arcade.matchmaking.snake")                 |
     |                               |                          |
     |←- FIND_VALUE_REPLY -----------|                          |
     |   subscribers: [peer1, peer2] |                          |
     |                               |                          |
     |-- RPC_CALL ----------------------------------→           |
     |   dest: peer2_node_id                         |          |
     |   method: "match_request"                     |          |
     |   params: {game: "snake", from: peer1}        |          |
     |                               |               ↓          |
     |                               |        Process request   |
     |                               |        Check availability|
     |                               |               |          |
     |←- RPC_REPLY ---------------------------------←           |
     |   result: {status: "accepted", game_id: "abc123"}       |
```

**Implementation**:
```elixir
# When player clicks "Find Match"
def handle_event("join_queue", _params, socket) do
  player_id = socket.assigns.player_id

  # Query DHT for other players
  case NodeManager.discover_subscribers("arcade.matchmaking.snake") do
    {:ok, []} ->
      # No other players, wait
      {:noreply, assign(socket, status: :waiting)}

    {:ok, subscribers} ->
      # Filter out self, try to match with first available
      other_players = Enum.reject(subscribers, fn sub ->
        sub.node_id == NodeManager.get_node_id()
      end)

      case try_match_with_players(player_id, other_players) do
        {:ok, game_id} ->
          {:noreply, assign(socket, status: :matched, game_id: game_id)}
        {:error, :no_available_players} ->
          {:noreply, assign(socket, status: :waiting)}
      end
  end
end

defp try_match_with_players(_player_id, []), do: {:error, :no_available_players}

defp try_match_with_players(player_id, [opponent | rest]) do
  # Send RPC request to opponent
  case NodeManager.call(
    opponent.node_id,
    "arcade.match_request",
    %{game: "snake", from: player_id}
  ) do
    {:ok, %{status: "accepted", game_id: game_id}} ->
      {:ok, game_id}

    {:ok, %{status: "rejected"}} ->
      # Try next opponent
      try_match_with_players(player_id, rest)

    {:error, _reason} ->
      # Opponent unreachable, try next
      try_match_with_players(player_id, rest)
  end
end
```

**RPC Handler** (receives match requests):
```elixir
# In MaculaArcade.Games.Coordinator

def handle_matchmaking_event(%{"type" => "rpc_request", "method" => "arcade.match_request", "params" => params}) do
  %{"game" => "snake", "from" => opponent_id} = params

  # Check if we can accept match
  case can_accept_match?() do
    true ->
      game_id = generate_game_id()
      start_game(opponent_id, game_id)
      {:reply, %{status: "accepted", game_id: game_id}}

    false ->
      {:reply, %{status: "rejected", reason: "already_in_game"}}
  end
end
```

---

### Phase 3: Game Synchronization (DHT Pub/Sub)

**Goal**: Real-time game state updates between matched players

**Flow**:
```
Player 1                            DHT                     Player 2
     |                               |                          |
     |-- SUBSCRIBE -----------------→|                          |
     |   topic: "arcade.game.abc123.state"                     |
     |                               |←-- SUBSCRIBE ------------|
     |                               |                          |
     |-- PUBLISH -------------------→|                          |
     |   topic: "arcade.game.abc123.state"                     |
     |   payload: {type: "input", direction: "up"}             |
     |                               |-- DELIVER ------------→  |
     |                               |                          |
     |                               |←- PUBLISH ---------------|
     |                               |   payload: {type: "input", direction: "down"}
     |←- DELIVER --------------------|                          |
```

**Implementation**:
```elixir
# After match accepted

def start_game(opponent_id, game_id) do
  # Subscribe to game-specific topic
  game_topic = "arcade.game.#{game_id}.state"
  {:ok, _ref} = NodeManager.subscribe(game_topic, fn event ->
    handle_game_event(event)
  end)

  # Start local game server
  {:ok, _pid} = GameServer.start_link(
    game_id: game_id,
    player1: self_player_id(),
    player2: opponent_id
  )

  # Publish game start event
  NodeManager.publish(game_topic, %{
    type: "game_started",
    game_id: game_id,
    players: [self_player_id(), opponent_id]
  })
end

# Handle player input
def handle_event("keydown", %{"key" => key}, socket) do
  direction = parse_direction(key)
  game_topic = "arcade.game.#{socket.assigns.game_id}.state"

  # Publish input to both players
  NodeManager.publish(game_topic, %{
    type: "player_input",
    player_id: socket.assigns.player_id,
    direction: direction,
    timestamp: System.system_time(:millisecond)
  })

  {:noreply, socket}
end

# Receive opponent's input
def handle_game_event(%{"type" => "player_input", "player_id" => player_id, "direction" => direction}) do
  # Update game state with opponent's move
  GameServer.apply_input(player_id, direction)
end
```

---

## Message Flow Summary

### Matchmaking Flow (Complete)

```
1. Both players subscribe to "arcade.matchmaking.snake" (DHT Pub/Sub)
   → DHT stores both subscriptions

2. Player 1 clicks "Find Match"
   → Queries DHT for subscribers (DHT FIND_VALUE)
   → Gets list: [peer1, peer2]

3. Player 1 sends match request to Player 2 (DHT RPC)
   → RPC routes via DHT multi-hop to peer2
   → Player 2 accepts/rejects
   → RPC reply routes back to peer1

4. If accepted, both subscribe to "arcade.game.{game_id}.state" (DHT Pub/Sub)
   → Game state updates broadcast to both players
```

---

## Why This Design is Correct

### DHT Pub/Sub for Matchmaking Discovery
✅ **Broadcast pattern**: All players see availability
✅ **Asynchronous**: Players come and go dynamically
✅ **Scalable**: DHT handles many subscribers
✅ **Decentralized**: No matchmaking server needed

### DHT RPC for Match Negotiation
✅ **Point-to-point**: Request goes to specific opponent
✅ **Synchronous**: Get immediate accept/reject
✅ **Reliable**: RPC has timeout and error handling
✅ **Stateful**: Can check availability before accepting

### DHT Pub/Sub for Game State
✅ **Low latency**: Direct routing via DHT
✅ **Multicast**: Both players get same updates
✅ **Order-preserving**: Message sequence maintained
✅ **Real-time**: No request/response overhead

---

## Implementation Checklist

### Erlang (Macula Core)

- [x] DHT-routed RPC (`macula_rpc_routing.erl`)
- [x] DHT-routed Pub/Sub (`macula_pubsub_routing.erl`)
- [x] DHT FIND_VALUE multi-value support
- [ ] Enable DHT routing by default (currently gateway routing)

### Elixir (Macula-Arcade)

- [ ] `NodeManager.discover_subscribers/1` - Query DHT for subscribers
- [ ] `NodeManager.call/3` - Send DHT-routed RPC
- [ ] Update `Coordinator` to use DHT RPC for match requests
- [ ] Update `Coordinator` to handle incoming RPC match requests
- [ ] Game-specific pub/sub topics for state sync

---

## Testing Plan

### Unit Tests
- [ ] DHT returns multiple subscribers
- [ ] RPC routes to correct peer via DHT
- [ ] Pub/Sub delivers to all subscribers
- [ ] Match request/response flow

### Integration Tests
- [ ] 3-peer matchmaking (peer1 matches with peer2, peer3 waits)
- [ ] Concurrent match requests (race conditions)
- [ ] Player disconnect during matchmaking
- [ ] Player disconnect during game

### End-to-End Tests
- [ ] Full matchmaking flow (subscribe → discover → RPC → game)
- [ ] Game state synchronization
- [ ] Multiple concurrent games
- [ ] Gateway NOT involved in routing (verify P2P)

---

## References

- **DHT-Routed RPC**: `/home/rl/work/github.com/macula-io/macula/architecture/dht_routed_rpc.md`
- **DHT-Routed Pub/Sub**: `/home/rl/work/github.com/macula-io/macula/architecture/dht_routed_pubsub.md`
- **Gateway Responsibilities**: `/home/rl/work/github.com/macula-io/macula/architecture/GATEWAY_RESPONSIBILITIES.md`

---

**Status**: Design Complete - Ready for Implementation
**Last Updated**: 2025-11-17
