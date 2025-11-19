# Lobby & Snake Stable Design

## Overview

This document captures the brainstorming for replacing the simple "Find Game" button with a full lobby system where Snakemasters manage their stable of snakes.

## Core Concepts

### Snakemaster (the player)
- Name, Avatar
- Home peer (container they connected to)
- Stable of snakes they own
- Total wins/losses across all snakes

### Snake (the fighter)
- Name, Avatar/Color scheme
- Personality (asshole_factor 0-100)
- Stats: Wins, Losses, Total food eaten, Games played
- Owner (Snakemaster)
- Home peer (where snake "lives")

## Lobby View

Instead of listing players, **list snakes available to fight**:

```
+--------------------------------------------------+
|  SNAKE ARENA - Choose Your Opponent              |
+--------------------------------------------------+
|  "Venom" (peer1)             W:12 L:3    [Fight] |
|     Personality: Aggressive                       |
|     Master: @alice                                |
|                                                   |
|  "Slither" (peer2)           W:8  L:5    [Fight] |
|     Personality: Gentleman                        |
|     Master: @bob                                  |
|                                                   |
|  "Chaos" (gateway)           W:20 L:15   [Fight] |
|     Personality: Total Jerk                       |
|     Master: @charlie                              |
+--------------------------------------------------+
|  YOUR STABLE                                      |
|  Select snake to fight with: [Dropdown]           |
|  "Striker" - Competitive (W:5 L:2)               |
+--------------------------------------------------+
```

## Pub/Sub Topics

```
arcade.stable.presence        # Snakes entering/leaving arena
arcade.stable.{peer_id}       # Snakes available on specific peer
arcade.snake.{snake_id}.stats # Individual snake stat updates
arcade.challenge.{snake_id}   # Challenge a specific snake
arcade.leaderboard.update     # Global leaderboard changes
```

## Data Models

### Snake

```elixir
%Snake{
  id: "snake_abc123",
  name: "Venom",
  avatar: "snake_green",  # or color/pattern identifier
  personality: 75,        # asshole_factor
  owner_id: "snakemaster_xyz",
  peer_id: "peer1",
  stats: %{
    wins: 12,
    losses: 3,
    food_eaten: 234,
    games_played: 15
  },
  created_at: ~U[2024-01-15 10:30:00Z]
}
```

### Snakemaster

```elixir
%Snakemaster{
  id: "snakemaster_xyz",
  name: "alice",
  avatar: "avatar_1",
  home_peer: "peer1",
  snake_ids: ["snake_abc123", "snake_def456"],
  created_at: ~U[2024-01-15 10:00:00Z]
}
```

## Key Mechanics

### Snake Registration
When you connect, you either:
- Create new Snakemaster + starter snake (random personality)
- Or log in and your snakes become available in the arena

### Snake Ownership
- Snakes live on the peer where they were created
- Snakemaster can have snakes on multiple peers
- Future: Trade/transfer snakes between peers

### Matchmaking
1. You select YOUR snake from your stable
2. You challenge THEIR snake (or Quick Match for random)
3. Both snakes must be "in the arena" (owner online)
4. Snake's personality affects AI behavior during gameplay

### Stats Tracking
- Each snake has independent win/loss record
- Leaderboard ranks snakes, not masters
- Stats persist across sessions

## Implementation Phases

### Phase 1: Basic Lobby (1-2 days)
- Snake presence list (who's online)
- Basic UI showing available snakes
- Quick match from lobby
- Snake selection (if you have multiple)

### Phase 2: Profiles & Persistence (2-3 days)
- Persistent snake/master profiles (SQLite)
- Win/loss tracking per snake
- Global snake leaderboard
- Snake creation with name/personality

### Phase 3: Teams & Management (2-3 days)
- Multiple snakes per master
- Snake stable management UI
- Character selection before match
- Personality display and descriptions

### Phase 4: Social Features (1-2 days)
- Direct challenges to specific snakes
- Spectator mode for active games
- Lobby chat (optional)

**Total Estimate: ~1-2 weeks for full feature**

## Design Decisions

### 1. Persistence Strategy: Per-Peer SQLite
All data lives on the Snakemaster's home peer:
- Snakemaster profile, stats, achievements
- Snake profiles, stats, and **genomes (TWEANN)**
- SQLite database per peer

**Rationale**: Snakes "live" where they were created. Trading moves the data.

### 2. Snake Control: AI-Only (Spectator Mode)
- **No manual control** - snakes are controlled by their TWEANN neural networks
- Snakemasters are managers/trainers, not drivers
- The `asshole_factor` is actually part of the evolved genome
- Remove "use arrow keys" instructions from UI

### 3. Snake Acquisition
- **Starter snake** given on first connect (random genome)
- Mechanics for stable growth TBD (wins? breeding? random drops?)

### 4. Cross-Peer Mechanics
- **No remote control** - snakes only play from their home peer
- **Trading supported** - transfer snake genome + stats to another peer
- Details TBD

### 5. Snake Death/Lifespan
- **TBD** - permadeath vs eternal accumulation needs reflection

## TWEANN Integration (DXNN2)

Each snake is powered by an evolved neural network from Gene Sher's DXNN2 framework.

### Snake Genome Structure

Based on DXNN2's records.hrl, each snake stores:

```elixir
%SnakeGenome{
  # Core DXNN2 agent data
  agent_id: "agent_123",
  cortex_id: "cortex_456",

  # Neural topology
  neurons: [...],           # Evolved neuron configurations
  sensors: [...],           # Vision, proximity, food direction
  actuators: [...],         # Direction output

  # Evolution history
  evo_hist: [...],          # Mutation operators applied
  generation: 15,           # How many generations evolved
  fitness: 1250.5,          # Accumulated fitness score

  # Constraints/morphology
  constraint: %{
    morphology: :snake_fighter,
    neural_afs: [:tanh, :cos, :gaussian],
    mutation_operators: [...]
  }
}
```

### Snake Sensors (Inputs)
- **Vision**: Grid scan in facing direction
- **Food direction**: Relative vector to food
- **Enemy proximity**: Distance/direction to opponent
- **Wall proximity**: Distance to walls
- **Body awareness**: Own snake length and tail position

### Snake Actuators (Outputs)
- **Direction**: Output for {up, down, left, right}
- **Aggression**: Modulates risk-taking behavior

### Evolution Mechanics

**Per-Game Evolution**:
- After each game, winner's genome has higher fitness
- Loser's genome can still mutate/improve
- Stats inform fitness function

**Potential Future**:
- Breeding: Crossover of two snake genomes
- Population-level evolution per peer
- Training arenas (private practice)

### Integration Points

| Component | Location | Purpose |
|-----------|----------|---------|
| Genome storage | SQLite per peer | Persist evolved networks |
| Cortex/Exoself | GameServer | Run NN during gameplay |
| Mutation | Post-game | Apply mutation operators |
| Sensors | game_server.ex | Extract game state to inputs |
| Actuators | game_server.ex | Convert outputs to direction |

## Open Questions (Remaining)

1. **Snake death**: Permadeath after X losses? Or stats accumulate forever?

2. **Stable growth**: How do Snakemasters get new snakes?
   - Earn through wins?
   - Random drops?
   - Breeding two snakes?
   - Purchase with in-game currency?

3. **Trading mechanics**:
   - Direct peer-to-peer transfer?
   - Marketplace?
   - Trade history?

4. **Evolution pacing**:
   - How many mutations per generation?
   - When does evolution happen (after game? in background?)
   - Training mode for isolated practice?

5. **Fitness function design**:
   - Win/loss weight
   - Food eaten
   - Survival time
   - Opponent trapped
   - Style points?

## RPC Flows

### Lobby Join
1. Player opens lobby -> RPC `lobby.register` with master profile
2. Server adds snakes to presence, broadcasts on `arcade.stable.presence`
3. Client subscribes to lobby topics, receives current snake list

### Challenge Flow
1. Master selects their snake
2. Master clicks [Fight] on opponent snake
3. RPC `lobby.challenge` with {my_snake_id, their_snake_id}
4. Target receives challenge notification
5. Accept -> game starts, Decline -> notification

### Quick Match
1. Master selects their snake
2. Clicks Quick Match
3. RPC `lobby.quick_match` with {snake_id}
4. Server finds available opponent snake
5. Game starts automatically

## State Storage Considerations

### Per-Peer Storage
- Each peer stores its local snakes/masters in SQLite
- Snakes "live" on their home peer
- Presence broadcast when snake comes online

### Leaderboard Aggregation
- Option A: Gateway aggregates all stats (central authority)
- Option B: DHT-based distributed leaderboard
- Option C: Each peer publishes stats, clients aggregate

### Consistency
- Snake stats updated after each game
- Broadcast stat changes on `arcade.snake.{id}.stats`
- Eventually consistent across mesh

---

*Created: November 2024*
*Status: Brainstorming/Design*
