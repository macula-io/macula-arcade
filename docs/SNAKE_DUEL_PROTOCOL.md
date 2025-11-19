# Snake Duel Protocol Specification

Protocol specification for the Snake Duel game in Macula Arcade.

## Overview

Snake Duel is a competitive 2-player snake game where players compete to eat food and survive. The protocol enables decentralized matchmaking and distributed gameplay over the Macula mesh network.

## Game Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Tick rate | 200ms (5 ticks/sec) | Game update frequency |
| Grid size | 20x20 | Playing field dimensions |
| Initial length | 3 segments | Starting snake size |
| Food count | 1 | Items on field at once |
| Win score | 10 points | First to reach wins |
| Time limit | 3 minutes | Max game duration |
| Disconnect timeout | 10 seconds | Forfeit after disconnect |

## Win/Loss Conditions

| Condition | Result |
|-----------|--------|
| Hit wall | Lose |
| Hit self | Lose |
| Hit opponent body | Lose (snake that moved into other) |
| Head-to-head collision | Draw (both lose) |
| Opponent disconnects (10s) | Win by forfeit |
| First to 10 points | Win |
| Time limit reached | Higher score wins (or draw) |

## Events (PubSub)

All events use past tense. IDs are in payloads, not topic names.

### `arcade.snake.player_registered`

**Published when:** Player joins matchmaking queue

**Payload:**
```json
{
  "player_id": "string",
  "node_id": "binary",
  "timestamp": "iso8601",
  "player_name": "string"
}
```

**Subscribers:** Other coordinators (to update queue view)

---

### `arcade.snake.player_unregistered`

**Published when:** Player leaves matchmaking queue

**Payload:**
```json
{
  "player_id": "string",
  "node_id": "binary",
  "timestamp": "iso8601",
  "reason": "cancelled | matched | timeout"
}
```

**Subscribers:** Other coordinators (to update queue view)

---

### `arcade.snake.match_proposed`

**Published when:** Coordinator proposes a match between two players

**Payload:**
```json
{
  "match_id": "string (hash)",
  "player1_id": "string",
  "player1_node_id": "binary",
  "player2_id": "string",
  "player2_node_id": "binary",
  "proposed_by": "binary (node_id)",
  "timestamp": "iso8601"
}
```

**Subscribers:** Both player coordinators

---

### `arcade.snake.match_found`

**Published when:** Match is confirmed by both parties

**Payload:**
```json
{
  "match_id": "string",
  "player1_id": "string",
  "player1_node_id": "binary",
  "player2_id": "string",
  "player2_node_id": "binary",
  "host_node_id": "binary",
  "timestamp": "iso8601"
}
```

**Subscribers:** Both player coordinators, potential spectators

---

### `arcade.snake.game_started`

**Published when:** Host initializes game and is ready for input

**Payload:**
```json
{
  "match_id": "string",
  "host_node_id": "binary",
  "initial_state": {
    "snake1": {
      "player_id": "string",
      "segments": [[x, y], ...],
      "direction": "up | down | left | right"
    },
    "snake2": {
      "player_id": "string",
      "segments": [[x, y], ...],
      "direction": "up | down | left | right"
    },
    "food": [x, y],
    "scores": {"player1_id": 0, "player2_id": 0}
  },
  "timestamp": "iso8601"
}
```

**Subscribers:** Both players, spectators

---

### `arcade.snake.state_updated`

**Published when:** Each game tick completes

**Payload:**
```json
{
  "match_id": "string",
  "tick": "integer",
  "snake1": {
    "player_id": "string",
    "segments": [[x, y], ...],
    "direction": "up | down | left | right",
    "alive": "boolean"
  },
  "snake2": {
    "player_id": "string",
    "segments": [[x, y], ...],
    "direction": "up | down | left | right",
    "alive": "boolean"
  },
  "food": [x, y],
  "scores": {"player1_id": 0, "player2_id": 0},
  "timestamp": "iso8601"
}
```

**Subscribers:** Both players, spectators

---

### `arcade.snake.game_ended`

**Published when:** Game concludes (win/lose/draw/forfeit)

**Payload:**
```json
{
  "match_id": "string",
  "winner_id": "string | null (draw)",
  "loser_id": "string | null (draw)",
  "final_scores": {"player1_id": 0, "player2_id": 0},
  "reason": "score_limit | time_limit | collision | forfeit | draw",
  "duration_ms": "integer",
  "timestamp": "iso8601"
}
```

**Subscribers:** Both players, spectators, leaderboard service

---

## RPC Methods

All methods use imperative present tense.

### `arcade.snake.register_player`

**Purpose:** Add player to matchmaking queue

**Arguments:**
```json
{
  "player_id": "string",
  "player_name": "string"
}
```

**Returns:**
```json
{
  "success": "boolean",
  "queue_position": "integer",
  "estimated_wait_ms": "integer"
}
```

**Errors:**
- `already_registered`: Player already in queue
- `in_game`: Player currently in active game

---

### `arcade.snake.unregister_player`

**Purpose:** Remove player from matchmaking queue

**Arguments:**
```json
{
  "player_id": "string"
}
```

**Returns:**
```json
{
  "success": "boolean"
}
```

**Errors:**
- `not_registered`: Player not in queue

---

### `arcade.snake.find_opponents`

**Purpose:** Query waiting players in DHT

**Arguments:**
```json
{
  "exclude_player_id": "string",
  "limit": "integer (default: 10)"
}
```

**Returns:**
```json
{
  "opponents": [
    {
      "player_id": "string",
      "node_id": "binary",
      "timestamp": "iso8601",
      "player_name": "string"
    }
  ]
}
```

**Errors:**
- `dht_unavailable`: Cannot query DHT

---

### `arcade.snake.submit_action`

**Purpose:** Send player input to game host

**Arguments:**
```json
{
  "match_id": "string",
  "player_id": "string",
  "action": "up | down | left | right",
  "sequence": "integer"
}
```

**Returns:**
```json
{
  "accepted": "boolean",
  "tick": "integer"
}
```

**Errors:**
- `game_not_found`: Match ID invalid
- `not_your_turn`: Action rejected
- `game_ended`: Game already finished
- `invalid_action`: Cannot reverse direction

---

## State Machine

```
[Idle]
  → register_player
[Waiting]
  → unregister_player → [Idle]
  → match_found
[Matched]
  → game_started
[Playing]
  → state_updated (loop)
  → game_ended
[Ended]
  → (back to Idle)
```

### State Descriptions

| State | Description |
|-------|-------------|
| Idle | Not in queue, can register |
| Waiting | In queue, waiting for opponent |
| Matched | Opponent found, waiting for game start |
| Playing | Game in progress, can submit actions |
| Ended | Game finished, viewing results |

## Decentralized Matchmaking Algorithm

### Registration

1. Player calls `register_player`
2. Coordinator stores in local state
3. Coordinator sends STORE to DHT: `arcade.snake.queue` → player info
4. Coordinator publishes `player_registered`

### Match Discovery

1. After registration, coordinator calls `find_opponents`
2. DHT returns list of waiting players
3. Coordinator selects opponent with **lowest timestamp** (deterministic)
4. Coordinator publishes `match_proposed`

### Match Confirmation

1. Both coordinators receive `match_proposed`
2. Both verify:
   - Players still in queue
   - match_id = hash(sorted([player1_id, player2_id]) + timestamp)
3. Both publish `match_found` (idempotent)
4. Both remove players from queue

### Host Selection

Host is determined deterministically (both coordinators reach same conclusion):
- Host = coordinator with **lower node_id** (lexicographic)
- Alternative: host = coordinator of player with lower timestamp

### Conflict Resolution

**Problem:** Multiple coordinators try to match same player

**Solution:**
- Each player can only be matched once (first `match_found` wins)
- Subsequent match proposals are ignored
- TTL on "pending" state prevents deadlocks

## Error Handling

| Error | Cause | Recovery |
|-------|-------|----------|
| Match proposal timeout | Other coordinator unresponsive | Remove proposal, retry with next opponent |
| Game start timeout | Host failed to start | Cancel match, return players to queue |
| Player disconnect | Network failure | 10-second grace period, then forfeit |
| DHT unavailable | Network partition | Use local queue, retry DHT |
| Duplicate registration | Race condition | Reject second registration |

## Example Sequences

### Happy Path: Complete Game

```
1. Player A calls register_player
2. Coordinator A publishes player_registered
3. Player B calls register_player
4. Coordinator B publishes player_registered
5. Coordinator A calls find_opponents, finds Player B
6. Coordinator A publishes match_proposed
7. Both coordinators publish match_found
8. Coordinator A (host) starts GameServer
9. Coordinator A publishes game_started
10. Players submit actions via submit_action RPC
11. Host publishes state_updated every 200ms
12. Player A reaches 10 points
13. Host publishes game_ended (winner: A)
```

### Disconnect Forfeit

```
1-9. (same as happy path)
10. Player B disconnects (network failure)
11. Host detects no actions from B for 10 seconds
12. Host publishes game_ended (winner: A, reason: forfeit)
```

### Race Condition Resolution

```
1. Players A and B register simultaneously
2. Coordinators A and B both call find_opponents
3. Both see each other as only opponent
4. Both publish match_proposed with same match_id
5. Both receive both proposals (idempotent)
6. Both publish match_found
7. Game proceeds normally
```

## Future Enhancements

- **Spectator mode**: Subscribe to `state_updated` without playing
- **Replay system**: Store all `state_updated` events for playback
- **Leaderboard**: Aggregate `game_ended` events for rankings
- **Multiple game modes**: Free-for-all, teams
- **Power-ups**: Special food items with effects

## References

- [Protocol Design Practices](/home/rl/work/github.com/macula-io/macula/architecture/PROTOCOL_DESIGN_PRACTICES.md)
- [Distributed System Design Principles](/home/rl/work/github.com/macula-io/CLAUDE.md#distributed-system-design-principles)
