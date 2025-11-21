# Neural Integration Analysis: Aligning Lobby & TWEANN Vision

## Document Purpose

This document maps the alignment between two key design documents:
- **LOBBY_AND_STABLE_DESIGN.md** - Game design for Snakemaster lobby system
- **NEURAL_SNAKE_VISION.md** - Technical roadmap for TWEANN integration

**Created:** 2025-01-21
**Status:** Design Alignment & Integration Strategy

---

## Key Discovery: "Stable" Has Dual Meaning

### Game Design Meaning (LOBBY_AND_STABLE_DESIGN.md)
**"Stable"** = Collection of snakes owned by a Snakemaster (like a racing stable)

### RL Training Meaning (NEURAL_SNAKE_VISION.md)
**"Stable Master"** = Historical opponent pool that provides stable training targets

**Integration Insight:** These concepts are **complementary and can be unified**!

---

## Concept Alignment Matrix

| Concept | Lobby Design | Neural Vision | Integration Strategy |
|---------|--------------|---------------|---------------------|
| **Snake Ownership** | Snakemasters own multiple snakes | Agents evolve over generations | Each snake in stable = evolved agent lineage |
| **Personality** | asshole_factor (0-100) | Learned behavior from training | asshole_factor becomes NN input, behavior emerges |
| **Stats Tracking** | Wins, losses, food eaten per snake | Fitness scores, ELO ratings | Unify: stats feed fitness, ELO determines matchmaking |
| **Leaderboard** | Ranks snakes by wins/losses | League tiers (Bronze→Diamond) | Merge: leaderboard shows tier + stats |
| **Persistence** | SQLite per peer | Mnesia for genotypes | Both needed: SQLite for game data, Mnesia for TWEANN |
| **Evolution** | "Per-game evolution" mentioned | Self-play training with checkpoints | Snake wins → creates checkpoint for stable master pool |
| **AI Control** | "AI-only (spectator mode)" | Neural network decision-making | Perfect match: all snakes NN-controlled |
| **Home Peer** | Snakes live on creation peer | Phenotype spawns on local node | Same: genotype stored locally, phenotype runs locally |

---

## Unified Architecture Vision

### The Snakemaster's Stable = Personal Opponent Pool

**Core Insight:** Each Snakemaster's stable IS their personal opponent pool for self-play training.

```
Snakemaster "Alice"
├── Stable of Snakes (visible in lobby)
│   ├── "Venom" (Gen 15, ELO 1200, aggressive)  ← Current champion
│   ├── "Striker" (Gen 12, ELO 1150, balanced)   ← Recent challenger
│   ├── "Shadow" (Gen 8, ELO 1050, defensive)    ← Earlier generation
│   └── "Rookie" (Gen 1, ELO 800, starter)       ← Original snake
│
└── Hidden Training Pool (for self-play)
    ├── Venom_checkpoint_gen10 (ELO 1100)  ← Historical version
    ├── Venom_checkpoint_gen5 (ELO 950)    ← Earlier version
    └── Striker_checkpoint_gen8 (ELO 1000) ← Alternative lineage
```

**How It Works:**
1. **Public Snakes** (in stable): Available to fight in lobby
2. **Private Checkpoints**: Historical versions used for training
3. **Training Mode**: Snakemaster trains snakes against their own historical pool
4. **Arena Mode**: Snakes fight other Snakemasters' champions

---

## Integration Strategy

### Phase 1: Foundation (v0.2.0) - TWEANN + Basic Stable

**Merge:**
- Lobby Design Phase 1 (Basic Lobby)
- Neural Vision Milestone 1-3 (TWEANN integration, training ground, self-play)

**Implementation:**
```elixir
# Database Schema (SQLite per peer)
create table snakemasters (
  id TEXT PRIMARY KEY,
  name TEXT,
  avatar TEXT,
  home_peer TEXT,
  created_at DATETIME
)

create table snakes (
  id TEXT PRIMARY KEY,
  name TEXT,
  avatar TEXT,
  personality INTEGER,  -- 0-100 asshole_factor (initial, becomes learned)
  owner_id TEXT REFERENCES snakemasters(id),
  peer_id TEXT,
  agent_id TEXT,  -- TWEANN agent ID (in Mnesia)
  generation INTEGER,
  elo_rating REAL DEFAULT 1000.0,
  wins INTEGER DEFAULT 0,
  losses INTEGER DEFAULT 0,
  food_eaten INTEGER DEFAULT 0,
  games_played INTEGER DEFAULT 0,
  is_champion BOOLEAN DEFAULT false,  -- Currently visible in lobby
  created_at DATETIME
)

create table snake_checkpoints (
  id TEXT PRIMARY KEY,
  snake_id TEXT REFERENCES snakes(id),
  agent_id TEXT,  -- TWEANN checkpoint agent ID
  generation INTEGER,
  elo_rating REAL,
  created_at DATETIME
)
```

**Key Features:**
- ✅ Snakemaster registration (create account)
- ✅ Starter snake generation (random TWEANN agent)
- ✅ Snake stats tracking
- ✅ Basic lobby showing available snakes
- ✅ Training mode (headless, against own checkpoints)
- ✅ Arena mode (vs. other snakes)

---

### Phase 2: Neural Gameplay (v0.3.0) - Full Lobby + Evolution

**Merge:**
- Lobby Design Phase 2-3 (Profiles, Persistence, Teams)
- Neural Vision Milestone 4-6 (NN integration, UI, modes)

**New Game Modes:**

**1. Training Arena (Solo)**
```
┌────────────────────────────────────────────┐
│  TRAINING ARENA - Private Practice          │
├────────────────────────────────────────────┤
│  Select Snake: [Venom ▼]                   │
│  Training Curriculum: [Intermediate ▼]      │
│                                             │
│  Recent Training Results:                   │
│  • vs Shadow (Gen 8): WIN (fitness: 450)   │
│  • vs Striker (Gen 12): LOSS (fitness: 220)│
│  • vs Random Bot: WIN (fitness: 680)       │
│                                             │
│  [Start Training Session] (10 games)        │
└────────────────────────────────────────────┘
```

**2. Evolution Lab (Breeding)**
```
┌────────────────────────────────────────────┐
│  EVOLUTION LAB - Create New Snake          │
├────────────────────────────────────────────┤
│  Method: [Mutate Existing ▼]               │
│                                             │
│  Parent Snake: [Venom (Gen 15) ▼]          │
│  Mutation Strength: [●●●○○] Medium         │
│                                             │
│  Predicted Changes:                         │
│  • +2-5 neurons (topology expansion)       │
│  • ~15% weight perturbation                │
│  • May inherit aggressive behavior         │
│                                             │
│  Name New Snake: [__________]              │
│  [Create Snake] (Cost: 100 food tokens)    │
└────────────────────────────────────────────┘
```

**3. Champion Arena (PvP)**
```
┌────────────────────────────────────────────┐
│  CHAMPION ARENA - Challenge Others         │
├────────────────────────────────────────────┤
│  Your Snake: [Venom ▼]                     │
│                                             │
│  Available Opponents:                       │
│  ┌──────────────────────────────────────┐  │
│  │ "Slither" (peer2)      ELO: 1180     │  │
│  │   Master: @bob          W:8 L:5      │  │
│  │   Tier: Gold            [Challenge]  │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │ "Chaos" (gateway)      ELO: 1350     │  │
│  │   Master: @charlie      W:20 L:15    │  │
│  │   Tier: Platinum        [Challenge]  │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  [Quick Match] (auto-match by ELO)         │
└────────────────────────────────────────────┘
```

**Implementation:**
- ✅ Network topology visualization
- ✅ Snake evolution UI (mutation controls)
- ✅ Training history display
- ✅ ELO-based matchmaking
- ✅ League tier badges (Bronze, Silver, Gold, Platinum, Diamond)
- ✅ Spectator mode for ongoing games

---

### Phase 3: Social & Trading (v0.4.0) - Distributed Features

**Merge:**
- Lobby Design Phase 4 (Social Features)
- Neural Vision Milestone 7 (Mesh-Distributed Evolution)

**New Features:**

**1. Snake Trading**
```
┌────────────────────────────────────────────┐
│  SNAKE MARKET - Trade Snakes               │
├────────────────────────────────────────────┤
│  Your Listings:                             │
│  • "Shadow" (Gen 8, ELO 1050) - 500 tokens │
│                                             │
│  Available Snakes:                          │
│  ┌──────────────────────────────────────┐  │
│  │ "Titan" by @eve                      │  │
│  │   Gen 25, ELO 1450, Diamond tier     │  │
│  │   Price: 2000 tokens                 │  │
│  │   Network: 47 neurons, 8 layers      │  │
│  │   Lineage: Aggressive Hunter         │  │
│  │   [Buy] [Preview Genome]             │  │
│  └──────────────────────────────────────┘  │
└────────────────────────────────────────────┘
```

**2. Distributed Training Cluster**
```
┌────────────────────────────────────────────┐
│  TRAINING NETWORK - Mesh Status            │
├────────────────────────────────────────────┤
│  Connected Peers: 8                         │
│  Total Snakes in Network: 47                │
│  Training Games/Hour: 1,247                 │
│                                             │
│  Your Contribution:                         │
│  • 3 snakes shared for sparring             │
│  • 12 checkpoints in global pool            │
│  • 156 training games contributed           │
│                                             │
│  Network Champions:                         │
│  1. "Apex" by @alice (ELO 1520)            │
│  2. "Serpent" by @dave (ELO 1490)          │
│  3. "Venom" by YOU (ELO 1480) 🎉           │
└────────────────────────────────────────────┘
```

**Implementation:**
- ✅ Cross-peer opponent discovery (DHT)
- ✅ Genome export/import (binary serialization)
- ✅ Trading marketplace with token economy
- ✅ Distributed training coordination
- ✅ Global leaderboard aggregation
- ✅ Network effect: more peers = faster training

---

### Phase 4: Advanced RL (v1.0.0) - Production Features

**Merge:**
- Neural Vision Milestone 8 (Advanced Training Techniques)
- Full production readiness

**New Features:**

**1. Personality Clustering & Species**
```
┌────────────────────────────────────────────┐
│  SPECIES ANALYSIS - Behavioral Clusters    │
├────────────────────────────────────────────┤
│  Your Snakes by Species:                    │
│                                             │
│  🔴 Aggressive Hunters (2 snakes)          │
│     • Venom (Gen 15) - Alpha specimen      │
│     • Striker (Gen 12)                      │
│     Traits: Food-focused, risky maneuvers  │
│                                             │
│  🔵 Patient Survivors (1 snake)            │
│     • Shadow (Gen 8)                        │
│     Traits: Wall-hugging, defensive plays  │
│                                             │
│  🟢 Adaptive Opportunists (1 snake)        │
│     • Rookie (Gen 1) - Still learning      │
│     Traits: Balanced, situation-dependent  │
│                                             │
│  [View Species Tree] [Breed Hybrid]        │
└────────────────────────────────────────────┘
```

**2. Strategy Explainer**
```
┌────────────────────────────────────────────┐
│  STRATEGY INSIGHTS - Venom (Gen 15)        │
├────────────────────────────────────────────┤
│  Key Behaviors Learned:                     │
│                                             │
│  ✓ Food Pursuit (confidence: 92%)          │
│    "Venom aggressively chases food even    │
│     when risk is high. Sensor activation   │
│     shows strong food-direction response." │
│                                             │
│  ✓ Head-to-Head Aggression (confidence: 78%)│
│    "When near opponent, Venom tends to     │
│     close distance rather than retreat.    │
│     87% of neurons fire in approach mode." │
│                                             │
│  ✓ Space Control (confidence: 65%)         │
│    "Mid-game, Venom cuts off opponent      │
│     escape routes. Learned from Gen 10+."  │
│                                             │
│  [Saliency Map] [Activation Heatmap]       │
└────────────────────────────────────────────┘
```

**Implementation:**
- ✅ Behavioral clustering (K-means on gameplay traces)
- ✅ Species identification and labeling
- ✅ Strategy extraction (decision tree approximation)
- ✅ Saliency maps (which inputs matter most)
- ✅ Activation visualization
- ✅ Natural language explanations
- ✅ Full test coverage
- ✅ Production deployment guide

---

## Data Flow Integration

### Training Flow (Private)

```
Snakemaster logs in
  ↓
Selects snake "Venom" (Gen 15)
  ↓
Clicks "Train" → opens Training Arena
  ↓
System loads:
  • Venom's current agent (Mnesia)
  • Historical checkpoints (SQLite + Mnesia)
  • ELO-matched opponents from pool
  ↓
TrainingGym runs 10 episodes:
  • Venom vs Venom_Gen10 (ELO 1100)
  • Venom vs Striker_Gen8 (ELO 1000)
  • Venom vs Random bot (ELO 700)
  • ... (7 more games)
  ↓
Aggregate fitness: 4,520 avg
  ↓
Win rate: 70% → Promote to next curriculum tier
  ↓
Optional mutation: [Yes/No]
  ↓
If Yes:
  • Create Venom_Gen16 (mutated)
  • Save Venom_Gen15 as checkpoint
  • Update snake record: generation++, ELO updated
  ↓
Stats displayed in UI
```

### Arena Flow (Public)

```
Snakemaster selects "Venom"
  ↓
Clicks [Challenge] on "Slither" (peer2, ELO 1180)
  ↓
RPC sent to peer2: lobby.challenge
  {my_snake: "Venom", their_snake: "Slither"}
  ↓
Peer2 accepts (or declines)
  ↓
GameServer starts (on host peer, determined by protocol)
  ↓
Both agents loaded:
  • Venom's phenotype spawned (peer1)
  • Slither's phenotype spawned (peer2)
  ↓
Game runs at 50ms tick:
  • Both NNs queried each tick
  • State synchronized via pub/sub
  ↓
Game ends: Venom wins
  ↓
Stats updated on both peers:
  • Venom: wins++, ELO += 15
  • Slither: losses++, ELO -= 15
  ↓
Optional post-game mutation for both snakes
  ↓
Broadcast stat updates: arcade.snake.{id}.stats
  ↓
Lobby refreshes with new ELO ratings
```

---

## Persistence Strategy

### SQLite Schema (Per-Peer Game Data)

```sql
-- Game-level data (visible to players)
CREATE TABLE snakemasters (...);
CREATE TABLE snakes (...);
CREATE TABLE snake_checkpoints (...);
CREATE TABLE games (
  id TEXT PRIMARY KEY,
  snake1_id TEXT,
  snake2_id TEXT,
  winner_id TEXT,
  snake1_food INTEGER,
  snake2_food INTEGER,
  ticks_survived INTEGER,
  created_at DATETIME
);
CREATE TABLE snake_stats_history (
  id TEXT PRIMARY KEY,
  snake_id TEXT,
  elo_rating REAL,
  wins INTEGER,
  losses INTEGER,
  recorded_at DATETIME
);
```

### Mnesia Schema (TWEANN Data)

```erlang
% TWEANN genotypes (neural network blueprints)
-record(agent, {id, cortex_id, evo_hist, fitness, ...}).
-record(cortex, {id, neuron_ids, sensor_ids, actuator_ids, ...}).
-record(neuron, {id, layer, weights, af, ...}).
-record(sensor, {id, name, vl, ...}).
-record(actuator, {id, name, vl, ...}).
```

### Data Sync Points

| Event | SQLite Update | Mnesia Update | Mesh Broadcast |
|-------|---------------|---------------|----------------|
| Snake created | INSERT snakes | genotype:construct_agent | arcade.stable.presence |
| Game completed | UPDATE snakes stats, INSERT games | (none) | arcade.snake.{id}.stats |
| Snake evolved | UPDATE snakes (generation++) | genome_mutator:mutate | arcade.snake.{id}.evolved |
| Checkpoint saved | INSERT snake_checkpoints | (none, checkpoint already in Mnesia) | (none) |
| Snake traded | UPDATE snakes (owner_id, peer_id) | Export/import genotype | arcade.market.trade |

---

## Unified Feature Matrix

| Feature | Lobby Design | Neural Vision | Integration | v0.2.0 | v0.3.0 | v0.4.0 | v1.0.0 |
|---------|--------------|---------------|-------------|--------|--------|--------|--------|
| **Snakemaster Accounts** | ✓ | - | SQLite storage | ✅ | | | |
| **Snake Stable Management** | ✓ | - | UI + DB | ✅ | | | |
| **TWEANN Integration** | ✓ (mentioned) | ✓ | Mnesia + morphology | ✅ | | | |
| **Headless Training** | - | ✓ | TrainingGym | ✅ | | | |
| **Self-Play w/ Checkpoints** | - | ✓ | SelfPlayCoordinator | ✅ | | | |
| **ELO Ratings** | - | ✓ | EloTracker | ✅ | | | |
| **League Tiers** | - | ✓ | LeagueTiers | | ✅ | | |
| **Lobby UI** | ✓ | - | Phoenix LiveView | ✅ | ✅ | | |
| **Network Visualization** | - | ✓ | LiveView component | | ✅ | | |
| **Evolution UI** | ✓ (implied) | ✓ | Mutation controls | | ✅ | | |
| **Spectator Mode** | ✓ | - | PubSub subscribe | | ✅ | | |
| **Snake Trading** | ✓ | - | Marketplace UI | | | ✅ | |
| **Distributed Training** | - | ✓ | Mesh coordination | | | ✅ | |
| **Global Leaderboard** | ✓ | - | DHT aggregation | | | ✅ | |
| **Personality Clustering** | - | ✓ | Behavioral analysis | | | | ✅ |
| **Strategy Explainer** | - | ✓ | Interpretability tools | | | | ✅ |
| **Species Identification** | - | ✓ | Clustering + labels | | | | ✅ |

---

## Open Questions Resolution

### From LOBBY_AND_STABLE_DESIGN.md

**1. Snake death: Permadeath or eternal?**

**Proposed Answer:** **Soft permadeath with revival option**
- Snakes with 10+ consecutive losses enter "retired" state
- Retired snakes can't fight in arena but remain in stable
- Snakemasters can "revive" via mutation (creates new generation)
- Preserves lineage history without eternal accumulation

**2. Stable growth: How to get new snakes?**

**Proposed Answer:** **Multiple paths**
- **Starter:** Free snake on registration
- **Evolution:** Mutate existing snake (costs food tokens)
- **Breeding:** Crossover two snakes (costs tokens, v1.0.0)
- **Trading:** Buy from marketplace (costs tokens, v0.4.0)
- **Rewards:** Win tournaments, earn rare snakes (v1.0.0)

**3. Trading mechanics**

**Proposed Answer:** **Peer-to-peer + marketplace**
- Direct transfer: Send snake to friend (free, requires acceptance)
- Marketplace: List snake with price, others can buy
- Trade history tracked in SQLite
- Genome + stats transferred atomically
- Post-trade, seller loses ownership

**4. Evolution pacing**

**Proposed Answer:** **Player-controlled with cooldowns**
- Training: Unlimited headless games
- Mutation: Once per snake per day (or after 10 games)
- Checkpoints: Auto-save every 5 games
- Background evolution: Optional "auto-train" mode (v1.0.0)

**5. Fitness function**

**Proposed Answer:** **Multi-objective with weights**
```elixir
fitness = (ticks_alive * 1.0) +
          (food_eaten * 100.0) +
          (win_bonus * 1000.0) +
          (opponent_trapped_bonus * 200.0) +
          (style_points * 50.0)

where:
  win_bonus = 1.0 if won, 0.0 if lost
  opponent_trapped_bonus = reachable_space_differential
  style_points = head_to_head_approaches + risky_moves
```

---

## Implementation Priority

### Immediate (v0.2.0 - Week 1-3)

1. **Database Schema** (SQLite + Mnesia)
2. **Snakemaster Registration** (basic accounts)
3. **Snake Creation** (TWEANN agent generation)
4. **Training Gym** (headless simulation)
5. **Self-Play Coordinator** (checkpoint pool)
6. **Basic Lobby UI** (list snakes, select yours)

### Near-Term (v0.3.0 - Week 4-7)

7. **Network Visualization** (topology display)
8. **Evolution UI** (mutation controls)
9. **Arena Mode** (challenge specific snakes)
10. **ELO Matchmaking** (balanced matches)
11. **Spectator Mode** (watch games)
12. **League Tiers** (Bronze→Diamond badges)

### Mid-Term (v0.4.0 - Week 8-10)

13. **Snake Trading** (marketplace)
14. **Distributed Training** (mesh coordination)
15. **Global Leaderboard** (DHT aggregation)
16. **Token Economy** (food tokens for evolution/trading)

### Long-Term (v1.0.0 - Week 11-14)

17. **Personality Clustering** (species identification)
18. **Strategy Explainer** (interpretability)
19. **Breeding System** (crossover genetics)
20. **Tournament Mode** (bracketed competitions)
21. **Production Hardening** (tests, docs, deployment)

---

## Success Metrics (Revised)

### v0.2.0 (Foundation)
- [ ] Create account and get starter snake
- [ ] Train snake in headless mode (1000+ games/hour)
- [ ] Self-play converges (win rate stabilizes)
- [ ] Snake stats tracked correctly
- [ ] Basic lobby shows available snakes

### v0.3.0 (Neural Gameplay)
- [ ] Challenge specific snake, game works
- [ ] Network topology visible during game
- [ ] Evolve snake via mutation UI
- [ ] ELO ratings adjust after games
- [ ] 70%+ users engage with evolution features

### v0.4.0 (Distributed)
- [ ] Trade snake between peers successfully
- [ ] Distributed training cluster with 5+ peers
- [ ] Global leaderboard shows top 100 snakes
- [ ] Token economy functional (earn/spend)

### v1.0.0 (Production)
- [ ] Behavioral clustering identifies 5+ species
- [ ] Strategy explainer provides insights
- [ ] Breeding creates hybrid snakes
- [ ] Full test coverage (>80%)
- [ ] Production docs complete
- [ ] 100+ active snakes in network

---

## Architecture Diagram (Unified)

```
┌─────────────────────────────────────────────────────────────┐
│                    SNAKEMASTER CLIENT                        │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────────┐    │
│  │ Lobby UI   │  │ Training UI  │  │ Evolution Lab    │    │
│  │ (LiveView) │  │ (LiveView)   │  │ (LiveView)       │    │
│  └────────────┘  └──────────────┘  └──────────────────┘    │
└──────────────────────┬──────────────────────────────────────┘
                       │ Phoenix Channel / WebSocket
┌──────────────────────┴──────────────────────────────────────┐
│                  PHOENIX APPLICATION                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    Coordinator                          │ │
│  │  • Matchmaking logic                                   │ │
│  │  • Lobby presence management                           │ │
│  │  • RPC handling (challenge, accept)                    │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐ │
│  │ GameServer   │  │ TrainingGym  │  │ SelfPlayCoord    │ │
│  │ (Live Games) │  │ (Headless)   │  │ (Checkpoints)    │ │
│  └──────────────┘  └──────────────┘  └──────────────────┘ │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐ │
│  │ AgentManager │  │ EloTracker   │  │ LeagueTiers      │ │
│  │ (TWEANN)     │  │ (Ratings)    │  │ (Tiers)          │ │
│  └──────────────┘  └──────────────┘  └──────────────────┘ │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        ↓                             ↓
┌───────────────┐            ┌─────────────────┐
│  SQLite DB    │            │   Mnesia DB     │
│  (Per-Peer)   │            │  (TWEANN Data)  │
├───────────────┤            ├─────────────────┤
│ • Snakemasters│            │ • Agents        │
│ • Snakes      │            │ • Cortexes      │
│ • Checkpoints │            │ • Neurons       │
│ • Games       │            │ • Sensors       │
│ • Stats       │            │ • Actuators     │
└───────────────┘            └─────────────────┘
        │                             │
        └──────────────┬──────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│                   MACULA MESH (HTTP/3)                       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  DHT Pub/Sub Topics:                                   │ │
│  │  • arcade.stable.presence      (lobby presence)        │ │
│  │  • arcade.game.{id}.state      (game sync)            │ │
│  │  • arcade.snake.{id}.stats     (stat updates)         │ │
│  │  • arcade.market.trade         (trading)              │ │
│  │  • arcade.leaderboard.update   (rankings)             │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  DHT RPC Methods:                                      │ │
│  │  • lobby.challenge             (match request)         │ │
│  │  • lobby.accept                (match accept)          │ │
│  │  • market.buy                  (purchase snake)        │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Conclusion

**The lobby design and neural vision are perfectly aligned!**

Key Insights:
1. **"Stable"** as Snakemaster's collection naturally becomes their opponent pool
2. **AI-only control** requirement matches neural network gameplay
3. **Per-peer persistence** works for both game data (SQLite) and neural data (Mnesia)
4. **Evolution mechanics** unify: post-game mutations + checkpoint-based self-play
5. **Personality** bridges game design (asshole_factor) and RL (learned behavior)

**Recommendation:** Implement both documents as a **unified roadmap** with shared milestones.

---

**Document Version:** 1.0
**Last Updated:** 2025-01-21
