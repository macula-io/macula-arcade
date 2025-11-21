# Neural Snake Vision: TWEANN Integration Plan

## Document Overview

This document captures the comprehensive analysis and roadmap for integrating TWEANN (Topology and Weight Evolving Artificial Neural Networks) into the Snake Battle Royale game in macula-arcade.

**Date:** 2025-01-21
**Status:** Planning Phase
**Current Version:** v0.2.2 (Basic Snake Battle Royale)
**Target Release:** v1.0.0 (Production-Ready Neural Snake Ecosystem)

---

## Table of Contents

1. [Current Architecture Analysis](#current-architecture-analysis)
2. [TWEANN Integration Mechanics](#tweann-integration-mechanics)
3. [Proposed Game Mechanics](#proposed-game-mechanics)
4. [Training Infrastructure](#training-infrastructure)
5. [Self-Play and Stable Master](#self-play-and-stable-master)
6. [Release Plan](#release-plan)
7. [Technical Specifications](#technical-specifications)
8. [Risk Mitigation](#risk-mitigation)

---

## Current Architecture Analysis

### Game Mechanics

**Grid Specifications:**
- **Size:** 40x30 cells
- **Tick Rate:** 50ms (~20 FPS)
- **Coordinates:** Tuples `{x, y}` with origin at top-left

**Snake Data Structure:**
```elixir
player1_snake: [{5, 5}, {4, 5}, {3, 5}]  # Head is first element
player2_snake: [{35, 25}, {36, 25}, {37, 25}]
```

### Game State Structure

Located in `MaculaArcade.Games.Snake.GameServer.State`:

```elixir
defstruct [
  :game_id,                      # Unique game identifier
  :player1_id, :player2_id,      # Player identifiers
  :player1_snake, :player2_snake,  # Snake position lists
  :player1_direction, :player2_direction,  # Current direction atoms
  :player1_score, :player2_score,  # Food eaten count
  :food_position,                # {x, y} tuple
  :game_status,                  # :waiting | :running | :finished
  :winner,                       # nil | player_id | :draw
  :timer_ref,                    # GenServer timer reference
  :player1_asshole_factor,       # 0-100 personality trait
  :player2_asshole_factor,       # 0-100 personality trait
  player1_events: [],            # Event feed (recent 30 events)
  player2_events: []             # Event feed (recent 30 events)
]
```

### Current Bot AI

**File:** `apps/macula_arcade/lib/macula_arcade/games/snake/game_server.ex` (lines 594-704)

**Function Signature:**
```elixir
defp bot_choose_direction(snake, current_direction, food_position, other_snake, asshole_factor)
```

**Decision Inputs:**
1. Snake head position
2. Current direction (`:up`, `:down`, `:left`, `:right`)
3. Food position
4. Opponent snake (all segments)
5. Asshole factor (0-100 personality)

**Scoring Algorithm:**

The bot evaluates each possible direction using:

1. **Reachable Space** (priority #1): Flood-fill algorithm counts safe cells
   - 2x score multiplier
   - Trap detection: penalty if `space < snake_length + 3`

2. **Head-to-Head Avoidance**: Predicts opponent's next 4 positions
   - Penalty: `50 - (asshole_factor/2)` = 50 to 0
   - Assholes take more risks

3. **Food Distance**: Manhattan distance
   - Bonus: `(old_dist - new_dist) * 15`

4. **Wall Proximity**: Edge avoidance penalty

5. **Escape Routes**: Count safe neighbors (0-4)
   - Each route adds 5 points

6. **Asshole Behaviors:**
   - Space cutoff: Reduce opponent's reachable space
   - Food stealing: Aggressively pursue if opponent closer
   - Body blocking: Limit opponent's options
   - Magnitude proportional to `asshole_factor`

7. **Randomness**: 50-75 unit variance for unpredictability

### Game Loop

**Tick Cycle** (every 50ms):

```
1. Apply bot AI (if enabled) → update directions
2. Track direction changes as events
3. Move both snakes
4. Check collisions
5. If collision: game over, notify coordinator
6. If no collision:
   - Check food consumption (grow snake if eaten)
   - Spawn new food
7. Broadcast state via Macula mesh + Phoenix PubSub
8. Schedule next tick
```

**Collision Detection** (lines 347-379):

Priority order:
1. Head-to-head collision → `:draw`
2. Wall collision (outside 0-40, 0-30 bounds)
3. Self collision (head hits own body)
4. Other collision (head hits opponent body)

### Multiplayer Architecture

**Snake Duel Protocol v0.2.0** (DHT-based decentralized matching):

1. **Registration:** Player added to `waiting_players` map + DHT storage
2. **Discovery:** Scan DHT via RPC `arcade.snake.find_opponents`
3. **Proposal:** Match proposal published as event
4. **Confirmation:** Lower `node_id` becomes host
5. **Game Start:** Host starts `GameServer`, guest subscribes to state updates

**State Synchronization:**
- **Host:** Broadcasts state every 50ms via mesh pub/sub
- **Guests:** Subscribe to `arcade.game.#{game_id}.state` topic
- **Resilience:** Both Macula mesh and Phoenix PubSub used simultaneously

### Key Integration Point for Neural Networks

**Critical Location:** `game_server.ex` lines 194-201 (`handle_info(:tick)`)

**Current Implementation:**
```elixir
# Bot AI decision
new_direction = bot_choose_direction(snake, current_direction, food_position, other_snake, asshole_factor)
```

**Neural Network Replacement:**
```elixir
# Neural network decision
new_direction = neural_choose_direction(phenotype, snake, current_direction, food_position, other_snake, asshole_factor)
```

**Performance Constraint:** Decision must complete in **<40ms** to meet 50ms tick budget.

---

## TWEANN Integration Mechanics

### TWEANN Architecture Overview

**Based on:** DXNN2 (Distributed Erlang Neural Networks) by Gene Sher
**Library:** `macula-tweann` v0.9.0 (Erlang/OTP)

**Key Components:**
- **Sensors** (layer -1.0): Input interfaces with customizable sensor functions
- **Neurons** (layer 0.0-1.0): Processing units with weighted inputs, activation functions
- **Actuators** (layer 1.0): Output interfaces with customizable output functions
- **Cortex:** Central coordinator managing sense-think-act cycles
- **Agent:** Top-level container with evolutionary history and fitness tracking

### Genotype vs Phenotype

**Genotype (Blueprint):**
- Stored in Mnesia database as records
- Contains: topology, weights, activation functions, mutation history
- Persistent across generations

**Phenotype (Running Network):**
- Spawned as Erlang processes when needed
- Transient: created for evaluation, terminated after
- Process-per-neuron architecture enables parallelism

### Training/Evolution Mechanisms

**Evolutionary Strategy:** NEAT-inspired with DXNN2 heritage

**Mutation Operators:**

*Topological Mutations:*
- `add_neuron` - Insert neuron into connection
- `add_bias` - Add bias term to neuron
- `add_outlink` - Add output connection
- `add_inlink` - Add input connection
- `add_sensorlink` - Connect sensor to neuron
- `add_actuatorlink` - Connect neuron to actuator
- `outsplice` - Split connection with new neuron
- `add_sensor`, `add_actuator` - Add new input/output

*Parametric Mutations:*
- `mutate_weights` - Perturb synaptic weights
- `mutate_af` - Change activation function
- `mutate_aggr_f` - Change aggregation function
- `mutate_plasticity` - Modify learning parameters

**Training Flow:**
```erlang
genotype:construct_agent(Constraint)
  → constructor:construct(AgentId)
    → spawns sensors, neurons, actuators, cortex
      → exoself:start(AgentId, PopMonitorPid, OpMode)
        → Tuning loop: cortex:sync() → network evaluation → weight updates
```

### Performance Characteristics

**Real-Time Performance:**
- ✅ Single forward pass latency: **<1ms** typical
- ✅ Network evaluation cycle: **10-100ms** depending on size
- ✅ Suitable for 50ms game tick budget
- ✅ Process-based architecture supports parallel computation

**Scalability:**
- Tested with networks up to ~100 neurons
- Linear time complexity in network size
- Mnesia backend suitable for 100s of agents

### Integration Pattern (Elixir → Erlang)

**Initialization:**
```erlang
% 1. Initialize database at app startup
:gen_type.init_db()

% 2. Register morphology (custom inputs/outputs for game)
:morphology_registry.register(:snake_battle, MorphologyModule)

% 3. Create agent from constraint
constraint = #constraint{
  morphology: :snake_battle,
  neural_afs: [:tanh, :cos],
  mutation_operators: [
    {:add_bias, 10},
    {:add_neuron, 40},
    {:mutate_weights, 50}
  ]
}
{:ok, agent_id} = :genotype.construct_agent(constraint)

% 4. Build phenotype (spawn network processes)
phenotype = :constructor.construct(agent_id)

% 5. Evaluate network
:cortex.sync(phenotype.cortex_pid)
receive do
  {:cortex, _id, :evaluation_complete, outputs} -> outputs
after 30000 -> timeout
end

% 6. Cleanup
:constructor.terminate(phenotype)
```

**Custom Morphology for Snake Game:**

File: `apps/macula_arcade/priv/tweann/morphology_snake.erl`

```erlang
-module(morphology_snake).
-behaviour(morphology_behaviour).
-include_lib("macula_tweann/include/records.hrl").

-export([get_sensors/1, get_actuators/1]).

get_sensors(snake_battle) ->
    [#sensor{
        name = snake_vision_sensor,
        type = standard,
        scape = {private, snake_sim},
        vl = 16  % Vision grid + metadata
    }];
get_sensors(_) -> error(invalid_morphology).

get_actuators(snake_battle) ->
    [#actuator{
        name = snake_action_actuator,
        type = standard,
        scape = {private, snake_sim},
        vl = 4  % Four directions (softmax)
    }];
get_actuators(_) -> error(invalid_morphology).
```

### Input/Output Structure

**Sensor Input (VL=16):**
```elixir
[
  # Local grid view (5x5 flattened, simplified from 11x11 for performance)
  # Each cell: 0.0 (empty), 0.5 (food), 1.0 (wall/snake body)
  cell_00, cell_01, ..., cell_24,  # 25 values (reduced from initial proposal)

  # Or alternative: Ray-cast vision (8 directions)
  ray_up, ray_down, ray_left, ray_right,
  ray_up_left, ray_up_right, ray_down_left, ray_down_right,  # 8 values

  # Metadata
  current_direction_encoded,  # 0.0=up, 0.25=right, 0.5=down, 0.75=left
  food_relative_x,            # Normalized -1.0 to 1.0
  food_relative_y,            # Normalized -1.0 to 1.0
  self_length_normalized,     # Snake length / max_length
  opponent_length_normalized, # Opponent length / max_length
  asshole_factor_normalized   # 0.0 to 1.0
]
# Total: 8 (rays) + 6 (metadata) = 14 values (VL=14 more practical)
```

**Actuator Output (VL=4):**
```elixir
[
  up_score,     # Softmax probability for :up
  down_score,   # Softmax probability for :down
  left_score,   # Softmax probability for :left
  right_score   # Softmax probability for :right
]
```

**Action Selection:**
```elixir
# Take argmax of output vector
direction_index = Enum.max_by(0..3, fn i -> Enum.at(output_vector, i) end)
direction = [:up, :down, :left, :right] |> Enum.at(direction_index)
```

---

## Proposed Game Mechanics

### Mechanic A: Neural Evolution Arena ⭐ (Recommended)

**Concept:** Snakes controlled by evolved neural networks with visible personality traits.

**Features:**
- **NN-Controlled Opponents:** Replace bot AI with TWEANN networks
- **Visible Genotype Stats:** Display network size, generation, mutation count
- **Personality Preservation:** Asshole factor becomes learned behavior
- **Generational Battles:** Snakes carry lineage tags ("Gen 42 Snake")
- **Champion Preservation:** Best performers saved to Mnesia, can be challenged again

**Technical Implementation:**
- **Inputs (VL=14):** Ray-cast vision (8) + metadata (6)
- **Outputs (VL=4):** Softmax over 4 directions
- **Fitness Function:** `survival_ticks * 10 + food_eaten * 100 - collisions * 500`
- **Evolution:** After each game, winner mutates to create offspring

**Why This Works:**
- Leverages existing 50ms tick budget (<1ms NN inference)
- Visual differentiation: show network topology in UI
- Natural tournament structure (already have matchmaking)

---

### Mechanic B: Neural Swarm Mode

**Concept:** Multiple AI snakes compete simultaneously in free-for-all.

**Features:**
- **4-8 Snakes:** Mix of human + NN-controlled
- **Real-Time Evolution:** Dead snakes respawn as mutated offspring
- **Collective Learning:** Population evolves during gameplay
- **Spectator Mode:** Watch neural swarms compete
- **Leaderboard:** Track best lineages across sessions

**Technical Implementation:**
- Same I/O as Mechanic A
- GameServer manages multiple snake agents
- Async evolution: mutation in background GenServer
- Rolling population of 20-50 networks in memory

**Challenges:**
- More complex collision detection
- Higher mesh bandwidth (more state to sync)
- UI complexity (tracking multiple snakes)

---

### Mechanic C: Co-Evolution Mode

**Concept:** Human trains personal AI companion through gameplay.

**Features:**
- **Human + AI Team:** Human plays, AI learns from human decisions
- **Imitation Learning:** NN observes human inputs, predicts next move
- **Takeover Mode:** AI can take control when human is AFK
- **Performance Rating:** Show "AI Confidence" meter when predicting
- **Legacy Mode:** Export your trained AI for others to play against

**Technical Implementation:**
- **Supervised Learning:** Use human direction changes as labels
- **Dataset:** Store `game_state → human_action` tuples
- **Periodic Retraining:** Every 100 games, retrain network
- **Weight Backup:** Save checkpoints via `cortex:backup()`

**Why Interesting:**
- Creates emotional attachment to AI companion
- Gradual handoff from human to AI control
- Personalized AI playstyles emerge

---

### Mechanic D: Neural Gladiator Tournament

**Concept:** Bracketed tournament with evolution between rounds.

**Features:**
- **16-Snake Bracket:** Single elimination
- **Evolution Window:** Between rounds, winner mutates
- **Speciation:** Track neural "species" by topology similarity
- **Hall of Fame:** Persistent champion storage
- **Replay System:** Re-run historical matches

**Technical Implementation:**
- Coordinator manages tournament bracket
- Evolution happens server-side between matches
- Store all genotypes in Mnesia
- Replay via deterministic seed + recorded inputs

---

## Training Infrastructure

### Why Headless Training Ground is Critical

**Problems with Live Training:**
1. **Sample Inefficiency:** Real matches expensive (network latency, human waiting)
2. **No Curriculum:** Can't progressively increase difficulty
3. **Uncontrolled Fitness:** Real gameplay fitness is noisy
4. **Sequential:** One game at a time limits throughput
5. **Non-Deterministic:** Hard to validate improvements

**Benefits of Training Ground:**
1. **Sample Efficiency:** 1000+ games/hour vs. 10-20/hour live
2. **Curriculum Learning:** Start simple, gradually add complexity
3. **Fitness Shaping:** Control reward functions precisely
4. **Parallel Training:** Run 100s of simulations simultaneously
5. **Deterministic Testing:** Validate improvements without variance

### Proposed Architecture

```
macula_arcade/
  ├── games/
  │   ├── snake/
  │   │   ├── game_server.ex          # Existing multiplayer game
  │   │   ├── training_gym.ex         # NEW: Headless training environment
  │   │   ├── training_supervisor.ex  # NEW: Manage parallel gyms
  │   │   └── curriculum.ex           # NEW: Progressive difficulty
  │   └── neural/
  │       ├── agent_manager.ex        # NEW: TWEANN lifecycle
  │       ├── morphology_snake.erl    # NEW: Snake-specific I/O
  │       └── population_store.ex     # NEW: Mnesia wrapper
```

### Training Gym Implementation

**File:** `apps/macula_arcade/lib/macula_arcade/games/snake/training_gym.ex`

**Purpose:** Headless Snake environment with no mesh sync, no LiveView, pure simulation.

**Key Features:**
- Single-threaded simulation (no GenServer overhead)
- Deterministic physics (repeatable results)
- Fast-forward mode (no 50ms tick delay)
- Episode batching (evaluate N episodes for stable fitness)
- Observation builder (game state → NN input vector)
- Action decoder (NN output → direction atom)

**API:**
```elixir
defmodule MaculaArcade.Games.Snake.TrainingGym do
  def start_link(opts)

  # Evaluate agent over N episodes, return average fitness
  def evaluate_agent(gym_pid, agent_id, episodes \\ 10)

  # Run single episode, return final fitness
  defp run_episode(phenotype, curriculum)

  # Convert game state to NN input vector
  defp build_observation(snake, food, direction)

  # Query neural network for action
  defp query_network(phenotype, observation)

  # Calculate fitness from episode outcome
  defp calculate_fitness(ticks_alive, food_eaten, outcome)
end
```

**Fitness Function:**
```elixir
defp calculate_fitness(ticks_alive, food_eaten, outcome) do
  # Reward survival and food consumption
  base_fitness = ticks_alive * 1.0 + food_eaten * 100.0

  # Penalty for early collision
  collision_penalty = if outcome == :collision, do: -200.0, else: 0.0

  base_fitness + collision_penalty
end
```

### Curriculum System

**File:** `apps/macula_arcade/lib/macula_arcade/games/snake/curriculum.ex`

**Purpose:** Progressive difficulty levels for training.

**Difficulty Levels:**

**1. Beginner:**
```elixir
%{
  grid_size: {20, 15},           # Smaller arena
  initial_snake: [{5, 5}, {4, 5}, {3, 5}],
  food_strategy: :static,         # Food doesn't move
  opponent: nil,                  # No opponent
  max_ticks: 500
}
```

**2. Intermediate:**
```elixir
%{
  grid_size: {40, 30},           # Full arena
  initial_snake: [{5, 5}, {4, 5}, {3, 5}],
  food_strategy: :random,
  opponent: :simple_bot,          # Static heuristic bot
  max_ticks: 1000
}
```

**3. Advanced:**
```elixir
%{
  grid_size: {40, 30},
  initial_snake: [{5, 5}, {4, 5}, {3, 5}],
  food_strategy: :competitive,    # Food placement favors opponent
  opponent: :champion_network,    # Best evolved network
  max_ticks: 2000
}
```

### Parallel Training Supervisor

**File:** `apps/macula_arcade/lib/macula_arcade/games/snake/training_supervisor.ex`

**Purpose:** Manage multiple parallel training gyms for throughput.

**Implementation:**
```elixir
defmodule MaculaArcade.Games.Snake.TrainingSupervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Start 10 parallel training gyms
    children = for i <- 1..10 do
      Supervisor.child_spec(
        {MaculaArcade.Games.Snake.TrainingGym, [difficulty: :beginner]},
        id: {:training_gym, i}
      )
    end

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Distribute agents across gyms for parallel evaluation
  def evaluate_population(agent_ids) do
    gym_pids = Supervisor.which_children(__MODULE__)
                |> Enum.map(fn {_id, pid, _type, _modules} -> pid end)

    # Parallel evaluation with Task.async_stream
    agent_ids
    |> Task.async_stream(fn agent_id ->
      gym_pid = Enum.random(gym_pids)
      TrainingGym.evaluate_agent(gym_pid, agent_id)
    end, max_concurrency: 10)
    |> Enum.map(fn {:ok, result} -> result end)
  end
end
```

**Performance Target:** 1000+ game evaluations per hour on single machine.

---

## Self-Play and Stable Master

### The Moving Target Problem

In competitive RL, if both agents learn simultaneously:

**Problems:**
- **Moving Target:** Opponent's policy changes every episode
- **Catastrophic Forgetting:** Agent overfits to current opponent version
- **Oscillation:** Policies never converge (rock-paper-scissors cycles)
- **No Progress Signal:** Hard to tell if agent improved or opponent got worse

**Solution:** Self-play with historical opponents (AlphaGo, OpenAI Five, AlphaStar approach).

### Self-Play Coordinator

**File:** `apps/macula_arcade/lib/macula_arcade/games/neural/self_play_coordinator.ex`

**Purpose:** Manage self-play training with stable historical opponents (League Training).

**Architecture:**
```elixir
defmodule MaculaArcade.Games.Neural.SelfPlayCoordinator do
  use GenServer

  defstruct [
    :current_agent_id,       # Agent being trained
    :opponent_pool,          # List of {agent_id, elo_rating}
    :checkpoint_interval,    # How often to save checkpoint (e.g., 50 games)
    :games_played,
    :win_rate_window         # Track recent performance (rolling 20 games)
  ]

  def start_link(opts)
  def train_iteration(coordinator_pid)
end
```

**Training Loop:**
```elixir
def handle_call(:train_iteration, _from, state) do
  # 1. Select opponent from pool (70% historical, 30% current)
  opponent_id = select_opponent(state.opponent_pool, state.current_agent_id)

  # 2. Play game in training gym
  {:ok, result} = play_training_match(
    state.current_agent_id,
    opponent_id
  )

  # 3. Update win rate tracking
  new_window = [result | state.win_rate_window] |> Enum.take(20)
  win_rate = calculate_win_rate(new_window)

  # 4. Evolve current agent if performing well
  new_agent_id = if win_rate > 0.55 do
    # Agent is winning >55%, mutate to create next generation
    :genome_mutator.mutate(state.current_agent_id)
  else
    # Keep training current agent
    state.current_agent_id
  end

  # 5. Checkpoint: Add to pool periodically
  new_pool = if rem(state.games_played, state.checkpoint_interval) == 0 do
    # Add current agent to historical pool
    elo = estimate_elo(win_rate)
    [{state.current_agent_id, elo} | state.opponent_pool]
    |> Enum.take(20)  # Keep top 20 opponents
  else
    state.opponent_pool
  end

  new_state = %{state |
    current_agent_id: new_agent_id,
    opponent_pool: new_pool,
    games_played: state.games_played + 1,
    win_rate_window: new_window
  }

  {:reply, {:ok, win_rate}, new_state}
end
```

**Opponent Selection Strategy:**
```elixir
defp select_opponent(pool, current_id) do
  if :rand.uniform() < 0.3 do
    # 30% chance: play against current self
    current_id
  else
    # 70% chance: play against historical opponent
    # Weighted by ELO similarity (prefer close matches)
    pool
    |> Enum.reject(fn {id, _elo} -> id == current_id end)
    |> Enum.random()
    |> elem(0)
  end
end
```

### ELO Rating System

**File:** `apps/macula_arcade/lib/macula_arcade/games/neural/elo_tracker.ex`

**Purpose:** Track relative skill levels of agents in opponent pool.

**Implementation:**
```elixir
defmodule MaculaArcade.Games.Neural.EloTracker do
  @k_factor 32  # Rapid convergence for training

  def update_ratings(winner_elo, loser_elo) do
    expected_winner = 1.0 / (1.0 + :math.pow(10, (loser_elo - winner_elo) / 400))
    expected_loser = 1.0 / (1.0 + :math.pow(10, (winner_elo - loser_elo) / 400))

    new_winner_elo = winner_elo + @k_factor * (1.0 - expected_winner)
    new_loser_elo = loser_elo + @k_factor * (0.0 - expected_loser)

    {new_winner_elo, new_loser_elo}
  end

  def estimate_elo_from_win_rate(win_rate) do
    # Rough conversion: 50% win rate = 1000 ELO
    1000.0 + 400.0 * :math.log10(win_rate / (1.0 - win_rate))
  end
end
```

### League Tier System

**File:** `apps/macula_arcade/lib/macula_arcade/games/neural/league_tiers.ex`

**Purpose:** Multi-tier training league for diverse opponent exposure (AlphaStar-style).

**Tier Structure:**
```elixir
defmodule MaculaArcade.Games.Neural.LeagueTiers do
  def tiers do
    %{
      # Bronze: Simple heuristic bots
      bronze: [
        {:bot, :random_walker, 500},
        {:bot, :simple_chaser, 700}
      ],

      # Silver: Early neural networks (Gen 1-10)
      silver: load_checkpoint_range(1..10),

      # Gold: Mid-evolution (Gen 11-30)
      gold: load_checkpoint_range(11..30),

      # Platinum: Recent champions (Gen 31+)
      platinum: load_checkpoint_range(31..50),

      # Diamond: Top 5 all-time
      diamond: load_hall_of_fame(5)
    }
  end

  def select_opponent_by_tier(tier, current_elo) do
    # Select opponent from tier with ELO within ±200
    tiers()[tier]
    |> Enum.filter(fn {_id, elo} -> abs(elo - current_elo) < 200 end)
    |> Enum.random()
  end

  def promote_tier(current_tier, win_rate) do
    # Promote to next tier if win rate > 70%
    case {current_tier, win_rate > 0.7} do
      {:bronze, true} -> :silver
      {:silver, true} -> :gold
      {:gold, true} -> :platinum
      {:platinum, true} -> :diamond
      {tier, _} -> tier
    end
  end
end
```

**Benefits:**
1. **Monotonic Improvement:** Agent always has stable baseline (historical self)
2. **Curriculum Emergence:** Automatically progresses through difficulty tiers
3. **Diversity:** Exposed to multiple strategies, prevents overfitting
4. **Reproducibility:** Can replay against specific checkpoint
5. **Evaluation:** Clear performance metric (ELO vs. pool)

---

## Release Plan

### Timeline Summary

**Versioning Strategy:** Incremental releases from current v0.2.2

| Release | Duration | Key Features | Complexity |
|---------|----------|--------------|------------|
| **v0.2.2** | Current | Basic Snake Battle Royale (live) | - |
| **v0.3.0** | 3 weeks | TWEANN integration, training ground, self-play | Medium |
| **v0.4.0** | 4 weeks | Neural gameplay, UI, modes, export/import | High |
| **v0.5.0** | 3 weeks | Distributed training via mesh | Medium |
| **v1.0.0** | 4 weeks | Advanced RL, production-ready | High |
| **TOTAL** | **14 weeks** (~3.5 months) | Full neural snake ecosystem | - |

---

## Release v0.3.0: Foundation (3 weeks)

**Goal:** Integrate TWEANN library, create training infrastructure, no gameplay changes yet.

### Milestone 1: TWEANN Integration (Week 1)

**Tasks:**

1. **Add macula-tweann dependency**
   - Update `macula-arcade/system/mix.exs` with path dependency:
     ```elixir
     {:macula_tweann, path: "../../../macula-tweann"}
     ```
   - Initialize Mnesia in `Application.start_link`
   - Create database initialization script: `mix arcade.init_db`

2. **Create Snake morphology for TWEANN**
   - File: `apps/macula_arcade/priv/tweann/morphology_snake.erl`
   - Define sensors: `snake_vision_sensor` (VL=14: 8 ray-cast + 6 metadata)
   - Define actuators: `snake_action_actuator` (VL=4: direction softmax)
   - Register morphology at app startup

3. **Agent Manager GenServer**
   - File: `apps/macula_arcade/lib/macula_arcade/games/neural/agent_manager.ex`
   - Functions: `create_agent/1`, `load_agent/1`, `save_agent/1`, `mutate_agent/1`
   - Wraps TWEANN Erlang API with Elixir interface
   - Manages phenotype lifecycle (spawn/terminate)

4. **Population Store**
   - File: `apps/macula_arcade/lib/macula_arcade/games/neural/population_store.ex`
   - Mnesia wrapper for agent persistence
   - Functions: `list_agents/0`, `get_champion/0`, `save_checkpoint/2`
   - Migration helpers for schema updates

**Deliverables:**
- ✅ macula-tweann compiles as dependency
- ✅ Can create/mutate/save neural agents
- ✅ Unit tests for AgentManager
- ✅ Documentation for morphology design

---

### Milestone 2: Headless Training Ground (Week 2)

**Tasks:**

1. **Training Gym**
   - File: `apps/macula_arcade/lib/macula_arcade/games/snake/training_gym.ex`
   - Headless snake simulation (no LiveView, no mesh sync)
   - Functions: `evaluate_agent/3`, `run_episode/2`
   - Observation builder: convert game state → NN input vector
   - Action decoder: NN output → direction atom

2. **Curriculum System**
   - File: `apps/macula_arcade/lib/macula_arcade/games/snake/curriculum.ex`
   - 3 difficulty levels: beginner, intermediate, advanced
   - Progressive grid sizes, food strategies, opponent types
   - Configuration: initial snake position, max ticks, rewards

3. **Training Supervisor**
   - File: `apps/macula_arcade/lib/macula_arcade/games/snake/training_supervisor.ex`
   - Parallel gym workers (10 concurrent simulations)
   - Function: `evaluate_population/1` for batch fitness testing
   - Resource pooling for efficient evaluation

4. **Fitness Calculation**
   - Formula: `ticks_alive * 1.0 + food_eaten * 100.0 - collision_penalty`
   - Tracking: survival rate, food efficiency, collision types
   - Export fitness logs for analysis

**Deliverables:**
- ✅ Can train agents in headless environment
- ✅ Curriculum progression validates
- ✅ Parallel evaluation speeds up 10x
- ✅ Fitness metrics logged to files

---

### Milestone 3: Self-Play Infrastructure (Week 3)

**Tasks:**

1. **Self-Play Coordinator**
   - File: `apps/macula_arcade/lib/macula_arcade/games/neural/self_play_coordinator.ex`
   - Opponent pool management (top 20 historical checkpoints)
   - Opponent selection (70% historical, 30% current)
   - Win rate tracking (rolling 20-game window)
   - Checkpoint creation every 50 games

2. **ELO Rating System**
   - File: `apps/macula_arcade/lib/macula_arcade/games/neural/elo_tracker.ex`
   - K-factor: 32 for rapid convergence
   - Update after each match
   - Opponent selection weighted by ELO proximity

3. **League Tier System**
   - File: `apps/macula_arcade/lib/macula_arcade/games/neural/league_tiers.ex`
   - 5 tiers: Bronze (bots), Silver (Gen 1-10), Gold (Gen 11-30), Platinum (Gen 31+), Diamond (Hall of Fame)
   - Automatic promotion/demotion based on ELO
   - Load checkpoints by generation range

4. **Training Loop CLI**
   - File: `apps/macula_arcade/lib/macula_arcade/games/neural/training_cli.ex`
   - Mix task: `mix arcade.train --generations 100 --curriculum beginner`
   - Live progress output (TPS, win rate, best fitness)
   - Checkpoint saving every N generations

**Deliverables:**
- ✅ Self-play training runs end-to-end
- ✅ ELO ratings converge over 100 games
- ✅ Can train for 50+ generations overnight
- ✅ CLI tool for headless training

---

## Release v0.4.0: Neural Gameplay (4 weeks)

**Goal:** Integrate trained NNs into live gameplay, UI updates, player-facing features.

### Milestone 4: NN Game Integration (Week 4)

**Tasks:**

1. **Replace Bot AI with NN**
   - Modify: `apps/macula_arcade/lib/macula_arcade/games/snake/game_server.ex`
   - Replace `bot_choose_direction/5` (line 594) with `neural_choose_direction/5`
   - Load phenotype at game start
   - Query network during tick cycle (must complete <40ms)
   - Cleanup phenotype at game end

2. **Neural Agent Selection UI**
   - Modify: `apps/macula_arcade_web/lib/macula_arcade_web/live/snake_live.ex`
   - New button: "Challenge Neural Champion"
   - Dropdown: Select opponent from saved agents (Bronze/Silver/Gold tiers)
   - Display opponent stats: generation, ELO, win rate, network size

3. **Network Visualization**
   - Component: `apps/macula_arcade_web/lib/macula_arcade_web/live/components/network_viz.ex`
   - Show neural topology (sensors → neurons → actuators)
   - Animated: highlight active neurons during gameplay
   - Stats panel: network size, mutation count, lineage

4. **Performance Monitoring**
   - Track NN inference latency per tick
   - Alert if >40ms (exceeds budget)
   - Fallback to heuristic bot if timeout

**Deliverables:**
- ✅ Players can challenge neural opponents
- ✅ NN decision latency <10ms average
- ✅ Network topology visible in UI
- ✅ No gameplay regressions

---

### Milestone 5: Neural Evolution Mode (Week 5)

**Tasks:**

1. **Evolution Arena Game Mode**
   - New route: `/snake/evolution`
   - Matchmaking: human vs. current training agent
   - After game: agent mutates based on outcome
   - Display evolution history (family tree)

2. **Generational Tagging**
   - Add to game state: `neural_generation`, `neural_lineage`
   - Display in UI: "Fighting Gen 42 Snake (lineage: Alpha)"
   - Event feed: "Gen 42 evolved → Gen 43 (added 2 neurons)"

3. **Champion Hall of Fame**
   - Page: `/champions`
   - List top 10 agents by ELO
   - Stats: total games, win rate, avg survival time
   - Replay button: challenge historical champion

4. **Export/Import Trained Agents**
   - Function: `PopulationStore.export_agent/1` → binary file
   - Upload button: import community-trained agents
   - Sharing: download `.tweann` file for sharing

**Deliverables:**
- ✅ Evolution Arena mode playable
- ✅ Generational tags displayed
- ✅ Hall of Fame page functional
- ✅ Can export/import trained agents

---

### Milestone 6: Advanced Features (Week 6-7)

**Tasks:**

1. **Co-Evolution Mode (Mechanic C)**
   - Human plays, AI observes and learns
   - Collect dataset: game state → human action
   - Periodic retraining (every 100 games)
   - "AI Confidence" meter shows prediction accuracy
   - Takeover mode: AI plays when human AFK

2. **Neural Swarm Mode (Mechanic B)**
   - 4-8 snakes in free-for-all
   - Mix of human + neural agents
   - Real-time population evolution
   - Spectator mode for watching swarms

3. **Tournament Bracket Mode (Mechanic D)**
   - 16-agent single elimination
   - Evolution between rounds
   - Replay system with deterministic seeds
   - Champion crowned at end

4. **Personality Learning**
   - Remove hardcoded `asshole_factor`
   - Let NN learn aggressive/defensive styles
   - Behavioral clustering: identify "species"
   - UI labels: "Aggressive Hunter", "Patient Survivor", etc.

**Deliverables:**
- ✅ 3 game modes: Evolution Arena, Co-Evolution, Swarm
- ✅ Tournament system functional
- ✅ Personality clustering identifies 3-5 archetypes
- ✅ Full UI polish and documentation

---

## Release v0.5.0: Distributed Training (3 weeks)

**Goal:** Scale training across multiple nodes using Macula mesh.

### Milestone 7: Mesh-Distributed Evolution (Week 8-9)

**Tasks:**

1. **Distributed Population Manager**
   - Each mesh node holds subset of population
   - DHT-based agent discovery
   - Load balancing: distribute evaluation across nodes
   - Mesh pub/sub for fitness results

2. **Distributed Self-Play**
   - Opponent discovery via mesh RPC
   - Cross-node matches for training
   - Synchronize checkpoints via mesh broadcast
   - Consensus on champion selection

3. **Training Cluster Mode**
   - Multi-container deployment via docker-compose
   - 10+ training nodes coordinating via mesh
   - Central coordinator aggregates results
   - Speedup: 10x faster evolution

4. **Mesh Topology Visualization**
   - Integration with macula-console
   - Show training nodes on mesh map
   - Real-time training metrics (TPS, fitness)
   - Start/stop training clusters from UI

**Deliverables:**
- ✅ Training scales linearly with node count
- ✅ Cross-node matches work seamlessly
- ✅ Can train on 10+ containers simultaneously
- ✅ Console integration shows training status

---

## Release v1.0.0: Advanced RL & Production Release (4 weeks)

**Goal:** State-of-the-art RL techniques, curriculum learning, transfer learning. Production-ready neural snake ecosystem.

### Milestone 8: Advanced Training Techniques (Week 10-12)

**Tasks:**

1. **Curriculum Learning**
   - Automatic difficulty progression
   - Metrics: promote to next tier after 70% win rate
   - Adversarial training: focus on failure modes
   - Meta-learning: learn to learn faster

2. **Transfer Learning**
   - Pre-train on simple environments
   - Fine-tune on competitive play
   - Domain randomization: vary grid size, speeds
   - Multi-task learning: train on multiple game modes

3. **Behavioral Diversity**
   - Novelty search: reward unique behaviors
   - Quality diversity: Pareto front optimization
   - Archive of strategies (MAP-Elites)
   - Speciation via topology/behavior clustering

4. **Interpretability Tools**
   - Saliency maps: which grid cells matter most?
   - Activation visualization: what neurons respond to
   - Decision tree approximation for explainability
   - Strategy extraction: describe learned policy

**Deliverables:**
- ✅ Curriculum learning beats flat training by 30%
- ✅ Transfer learning reduces training time 50%
- ✅ Behavioral diversity yields 10+ distinct strategies
- ✅ Can explain agent decisions in natural language

---

## Technical Specifications

### Neural Network I/O Specification

**Input Vector (VL=14):**

```elixir
[
  # Ray-cast vision (8 directions)
  # Each ray: distance to nearest obstacle (0.0-1.0 normalized)
  ray_up,           # 0.0 = wall/snake at head, 1.0 = clear 40 cells
  ray_down,
  ray_left,
  ray_right,
  ray_up_left,
  ray_up_right,
  ray_down_left,
  ray_down_right,

  # Metadata (6 values)
  current_direction_encoded,  # 0.0=up, 0.25=right, 0.5=down, 0.75=left
  food_relative_x,            # Normalized -1.0 to 1.0
  food_relative_y,            # Normalized -1.0 to 1.0
  self_length_normalized,     # Snake length / max_possible_length
  opponent_length_normalized, # Opponent length / max_possible_length
  asshole_factor_normalized   # 0.0 to 1.0 (personality trait)
]
```

**Output Vector (VL=4):**

```elixir
[
  up_score,     # Softmax probability for :up
  down_score,   # Softmax probability for :down
  left_score,   # Softmax probability for :left
  right_score   # Softmax probability for :right
]
```

**Action Selection:**
```elixir
# Take argmax of output vector, respecting movement constraints
valid_directions = get_valid_directions(current_direction)
direction_scores = Enum.zip([:up, :down, :left, :right], output_vector)
  |> Enum.filter(fn {dir, _score} -> dir in valid_directions end)

{direction, _score} = Enum.max_by(direction_scores, fn {_dir, score} -> score end)
```

### Fitness Function Specification

**Primary Fitness:**
```elixir
fitness = (ticks_alive * 1.0) + (food_eaten * 100.0) + outcome_bonus
```

**Outcome Bonuses:**
- Win: +1000
- Draw: +200
- Loss: 0
- Collision penalties:
  - Wall: -200
  - Self: -300
  - Opponent: -100

**Secondary Metrics (for analysis, not fitness):**
- Average distance to food
- Reachable space over time
- Aggressive moves count (head-to-head approaches)
- Defensive moves count (wall hugging, retreat)

### Constraint Configuration

**Initial Constraint for Snake Agents:**

```erlang
#constraint{
  morphology = snake_battle,
  connection_architecture = recurrent,  % Allow memory
  neural_pfns = [none],                 % No plasticity initially
  neural_afs = [tanh, cos, gaussian],   % Activation functions
  tuning_selection_fs = [dynamic_random],
  tuning_duration_f = {wsize_proportional, 0.5},
  annealing_parameters = [0.5],
  perturbation_ranges = [1.0],
  agent_encoding_types = [neural],
  heredity_types = [darwinian],         % Pure evolution, no learning
  mutation_operators = [
    {mutate_weights, 50},
    {add_bias, 10},
    {remove_bias, 10},
    {mutate_af, 10},
    {add_outlink, 10},
    {add_inlink, 10},
    {add_neuron, 40},
    {outsplice, 20},
    {add_sensorlink, 5},
    {add_actuatorlink, 5}
  ],
  tot_topological_mutations_fs = [{ncount_exponential, 0.5}],
  population_evo_alg_f = generational,
  population_fitness_postprocessor_f = size_proportional,  % Penalize large networks
  population_selection_f = hof_competition,

  % Initial topology: simple feedforward
  substrate_plasticities = [none],
  substrate_linkforms = [l2l_feedforward]
}
```

### Performance Benchmarks

**Target Metrics:**

| Metric | Target | Critical Threshold |
|--------|--------|-------------------|
| NN Inference Latency | <10ms avg | <40ms max |
| Training Throughput | 1000+ games/hour | 500+ games/hour |
| Convergence Time | <100 generations | <200 generations |
| Memory per Agent | <10MB | <50MB |
| Parallel Gym Count | 10+ | 5+ |

**Hardware Assumptions:**
- CPU: 4+ cores @ 2.0GHz+
- RAM: 8GB+
- Storage: 1GB+ for Mnesia database

---

## Risk Mitigation

### Risk Matrix

| Risk | Likelihood | Impact | Mitigation Strategy |
|------|------------|--------|---------------------|
| **NN too slow for real-time** | Medium | High | Profile early (Milestone 4), optimize phenotype caching, consider model compression, use simpler topologies |
| **Training takes too long** | Medium | Medium | Start with small networks, parallel gyms, curriculum learning shortcut, distributed training (v1.1) |
| **Agents learn degenerate strategies** | High | Medium | Diverse opponent pool, fitness shaping, novelty rewards, behavioral diversity (v1.2) |
| **Mesh sync issues in distributed** | Low | Medium | Thorough testing in v1.1, fallback to single-node training, async checkpointing |
| **User confusion with neural UI** | Medium | Low | Progressive disclosure, tooltips, tutorial mode, simple defaults |
| **Mnesia scaling issues** | Low | Medium | Monitor DB size, implement pruning, consider external storage (PostgreSQL) for large populations |
| **TWEANN integration bugs** | Medium | High | Extensive unit tests, integration tests, gradual rollout, heuristic bot fallback |
| **Overfitting to training env** | High | Medium | Domain randomization, transfer learning, diverse opponents, real-game validation |

### Contingency Plans

**If NN inference is too slow:**
1. Cache phenotypes between ticks (reuse process)
2. Limit network size via fitness penalty
3. Pre-compile optimized networks
4. Fall back to heuristic bot for complex networks

**If training doesn't converge:**
1. Simplify fitness function
2. Increase population size
3. Reduce mutation rate
4. Seed with heuristic bot behavior

**If Mnesia hits limits:**
1. Implement agent pruning (keep top N)
2. Archive old generations to disk
3. Migrate to PostgreSQL for genotypes
4. Distributed Mnesia across nodes (v1.1)

**If users don't engage:**
1. Simplify onboarding (pre-trained agents)
2. Add social features (sharing, leaderboards)
3. Gamify training (XP, achievements)
4. Create viral moments (epic replays)

---

## Success Metrics

### Release v0.3.0 Success Criteria

- [ ] Train agent to 80% win rate vs. random bot
- [ ] Self-play converges within 100 generations
- [ ] Training throughput: 1000+ games/hour
- [ ] Zero crashes during 1000-game training session
- [ ] Documentation covers all APIs

### Release v0.3.0 Success Criteria

- [ ] Neural opponent feels "challenging but fair" (user survey)
- [ ] 70%+ users try Evolution Arena mode
- [ ] Network visualization gets positive feedback
- [ ] NN inference <10ms average latency
- [ ] Can export/import agents successfully
- [ ] Hall of Fame displays correct stats

### Release v0.5.0 Success Criteria

- [ ] 10-node cluster trains 10x faster than single node
- [ ] Cross-node matches have <100ms latency
- [ ] Distributed checkpointing works reliably
- [ ] Mesh topology visible in macula-console
- [ ] Zero data loss during distributed training

### Release v1.0.0 Success Criteria (Production Release)

- [ ] Curriculum learning reduces training time 50%
- [ ] Users can identify 5+ distinct AI personalities
- [ ] Explainability tools used in 30% of games
- [ ] Transfer learning demonstrates knowledge reuse
- [ ] Behavioral diversity archive contains 20+ strategies
- [ ] Full test coverage (>80%)
- [ ] Performance benchmarks met
- [ ] Production deployment documentation complete

---

## Appendix: File Structure

### New Files to Create

```
macula_arcade/
├── system/
│   └── apps/
│       ├── macula_arcade/
│       │   ├── lib/macula_arcade/
│       │   │   └── games/
│       │   │       ├── neural/
│       │   │       │   ├── agent_manager.ex              # NEW
│       │   │       │   ├── population_store.ex           # NEW
│       │   │       │   ├── self_play_coordinator.ex      # NEW
│       │   │       │   ├── elo_tracker.ex                # NEW
│       │   │       │   ├── league_tiers.ex               # NEW
│       │   │       │   └── training_cli.ex               # NEW
│       │   │       └── snake/
│       │   │           ├── training_gym.ex               # NEW
│       │   │           ├── training_supervisor.ex        # NEW
│       │   │           └── curriculum.ex                 # NEW
│       │   └── priv/
│       │       └── tweann/
│       │           └── morphology_snake.erl              # NEW
│       └── macula_arcade_web/
│           └── lib/macula_arcade_web/
│               └── live/
│                   └── components/
│                       └── network_viz.ex                # NEW
└── NEURAL_SNAKE_VISION.md                                # THIS FILE
```

### Modified Files

```
macula_arcade/
├── system/
│   ├── mix.exs                                           # Add macula_tweann dep
│   └── apps/
│       ├── macula_arcade/
│       │   ├── lib/macula_arcade/
│       │   │   ├── application.ex                        # Init Mnesia
│       │   │   └── games/
│       │   │       └── snake/
│       │   │           └── game_server.ex                # Replace bot AI
│       │   └── mix.exs                                   # Add neural deps
│       └── macula_arcade_web/
│           └── lib/macula_arcade_web/
│               ├── live/
│               │   ├── snake_live.ex                     # Add NN selection UI
│               │   └── home_live.ex                      # Add mode buttons
│               └── router.ex                             # Add /evolution route
```

---

## Document Changelog

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-01-21 | 1.0.0 | Initial comprehensive analysis and roadmap | Claude Code |
| 2025-01-21 | 1.1.0 | Updated versioning strategy to incremental (v0.3.0 → v1.0.0) | Claude Code |
| 2025-01-21 | 1.2.0 | Synced version numbers with existing v0.2.2 tag | Claude Code |

---

## References

### Technical Papers

- **NEAT (NeuroEvolution of Augmenting Topologies):** Stanley & Miikkulainen, 2002
- **AlphaStar (League Training):** Vinyals et al., 2019
- **MAP-Elites (Quality Diversity):** Mouret & Clune, 2015
- **HyperNEAT:** Stanley et al., 2009

### Implementation References

- **DXNN2:** Gene Sher's Handbook of Neuroevolution Through Erlang
- **macula-tweann:** `/home/rl/work/github.com/macula-io/macula-tweann`
- **macula-arcade:** `/home/rl/work/github.com/macula-io/macula-arcade`

### External Resources

- Erlang/OTP Documentation: https://erlang.org/doc/
- Elixir Phoenix LiveView: https://hexdocs.pm/phoenix_live_view/
- Mnesia Database: https://erlang.org/doc/man/mnesia.html

---

**END OF DOCUMENT**
