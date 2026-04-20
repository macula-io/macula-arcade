# Snake Duel Separation Plan

**Date:** 2025-12-04
**Priority:** Later (After LTC)
**Status:** In Progress - TWEANN Integration Working

---

## Architectural Vision (Auth in Console)

```
┌─────────────────────────────────────────────────────────────────────┐
│  MACULA CONSOLE (Home Node @ console.macula.local)                  │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  USER IDENTITY (Console owns authentication)                │   │
│  │  - id, username, password_hash, email                       │   │
│  │  - avatar_url, location, country_code                       │   │
│  │  - /login, /register, /logout routes                        │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐                      │
│  │  Arcade    │ │  Settings  │ │  [Apps]    │                      │
│  │  Launcher  │ │            │ │            │                      │
│  └─────┬──────┘ └────────────┘ └────────────┘                      │
│        │                                                            │
│        │ X-Console-User-Id header                                   │
│        ▼                                                            │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  SNAKE DUEL (auth-less, receives user_id from Console)      │   │
│  │  - SnakeMaster (game profile, NOT auth entity)              │   │
│  │  - console_user_id (reference, not foreign key)             │   │
│  │  - display_name, coins, reputation, snakes[]                │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Completed Progress

### v0.3.1 (macula-arcade)
- ✅ Updated macula dependency to v0.14.1
- ✅ Extracted 14 LiveView components
- ✅ Added NAT/Tech Info Panel
- ✅ Renamed lobby buttons: "TRAINING" / "COMBAT"
- ✅ Added game mode badge to game header
- ✅ Added snake stats display in player panel

### v0.4.0 (macula-arcade)
- ✅ TWEANN snake configuration (presets + advanced params)
- ✅ Snake selection modal in lobby
- ✅ Player info display in game header
- ⚠️ Auth implemented but will move to Console in separation

### Phase 3: TWEANN Integration ✅ IN PROGRESS
1. ✅ Add macula_tweann dependency to mix.exs
2. ✅ Create snake morphology in `lib/snake_duel/brain/`:
   - `morphology.ex` - Implements `:morphology_behaviour` (42 inputs, 6 outputs)
   - `sensors.ex` - Translates game state to neural inputs
   - `actuators.ex` - Translates network outputs to game directions
   - `brain.ex` - High-level wrapper for macula_tweann
3. ✅ Created `network_evaluator.erl` in macula-tweann
4. ✅ Connect TWEANN to game loop via `bot_type: :tweann`
5. ✅ Test AI-controlled snakes - WORKING!

---

## Remaining Implementation

### Phase 4: Brain Visualization (NEXT)
1. ⬜ TWEANN brain visualization component
   - Display actual network topology
   - Show neurons arranged by layer
   - Visualize connections with weight strength
   - Show activation levels during gameplay
2. ⬜ Real-time updates during game tick
3. ⬜ Integration into game UI (sidebar or overlay)

### Phase 5: TWEANN Evolution & Training
1. ⬜ Implement fitness function based on game performance
2. ⬜ Add mutation operators for network weights
3. ⬜ Population management for training sessions
4. ⬜ Save/load trained brains to database

### Phase 6: Crossbreeding & Speciation
1. ⬜ Sexual reproduction (crossover)
2. ⬜ Speciation mechanism
3. ⬜ Breeding UI in the Stable
4. ⬜ Lineage tracking

---

## Snake Duel Module Architecture

```
lib/snake_duel/
├── player/                 # Player identity (linked to Console user)
├── snake/                  # Snake entities
├── neural/                 # Brain/perception
│   ├── morphology/
│   ├── sensor.ex
│   └── actuator.ex
├── evolution/              # Genetic algorithms
├── culture/                # Social/behavioral memory
├── market/                 # In-game economy
└── arena/                  # Game environment
```

---

## Sensor Architecture (42 inputs)

| Category | Inputs | Description |
|----------|--------|-------------|
| **Vision Cone** | 8 rays × 4 channels = 32 | Distance to: food, enemy, self, wall |
| **Self-Awareness** | 4 neurons | Length, energy, speed, health |
| **Position** | 2 neurons | Normalized x, y |
| **Compass** | 4 neurons | N/E/S/W one-hot |

## Actuator Architecture (6 outputs)

| Output | Range | Description |
|--------|-------|-------------|
| turn_left | -1.0 to 1.0 | Turning intention |
| turn_right | -1.0 to 1.0 | Turning intention |
| forward_bias | 0.0 to 1.0 | Prefer forward |
| speed_boost | 0.0 to 1.0 | Boost multiplier |
| confidence | 0.0 to 1.0 | Action certainty |
| aggression | 0.0 to 1.0 | Attack vs evade |

---

## Database Strategy

- **SQLite3** for Ecto schemas (players, snakes, matches, stats)
- **Mnesia** for TWEANN genomes (macula_tweann's native storage)
- Both stored on `/bulk` drive for persistence
