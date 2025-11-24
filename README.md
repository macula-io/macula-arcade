# Macula Arcade

**Interactive multiplayer arcade platform demonstrating [Macula](https://github.com/macula-io/macula) HTTP/3 mesh networking**

[![Macula Version](https://img.shields.io/badge/macula-v0.10.0-blue)](https://hex.pm/packages/macula)
[![Snake Protocol](https://img.shields.io/badge/protocol-v0.2.0-green)](docs/architecture/SNAKE_DUEL_ARCHITECTURE.md)

---

## What is Macula Arcade?

Macula Arcade showcases **decentralized gaming** over a mesh network. Players discover each other automatically, matchmake across nodes, and play in real-time - no central server required.

### Current Features

- ✅ **Snake Duel** - 2-player competitive snake game
- ✅ **Cross-node matchmaking** - Players on different servers automatically matched
- ✅ **Real-time sync** - 60 FPS game loop over HTTP/3 (QUIC)
- ✅ **Platform Layer** - Leader election, distributed state (Raft + CRDTs)
- ✅ **Browser-based** - No downloads, just open http://localhost:4000

---

## Quick Start

### 🎮 Try the Demo (Pre-built Images)

```bash
cd docker/demo
./deploy-demo.sh
```

Open http://localhost:4000 and click "Find Game"!

See [docker/demo/](docker/demo/) for details.

### 🔧 Development Mode

```bash
cd docker/dev
./deploy-dev.sh
```

Development environment with hot-reload on ports 5000-5003.

See [docker/dev/](docker/dev/) for details.

### 🧪 Test Latest Code

```bash
cd docker/test
./test.sh rebuild
```

Tests unreleased features from local repos.

See [docker/test/README.md](docker/test/README.md) for details.

---

## Architecture

### The Stack

```
┌─────────────────────────────────────────────┐
│      Phoenix LiveView (Web UI)              │
│   ┌────────────┐       ┌──────────────┐    │
│   │ Snake UI   │       │Canvas Render │    │
│   └────────────┘       └──────────────┘    │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────┴──────────────────────────┐
│   Macula Platform (HTTP/3 mesh)             │
│ ┌─────────┐ ┌─────────┐ ┌──────────────┐   │
│ │ Raft    │ │ CRDTs   │ │ DHT Pub/Sub  │   │
│ │ Leader  │ │ State   │ │ Events       │   │
│ └─────────┘ └─────────┘ └──────────────┘   │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────┴──────────────────────────┐
│      Game Engine (Elixir/OTP)               │
│ ┌────────────┐         ┌──────────────┐    │
│ │GameServer  │         │ Coordinator  │    │
│ │(60 FPS)    │         │(Matchmaking) │    │
│ └────────────┘         └──────────────┘    │
└─────────────────────────────────────────────┘
```

### How Matchmaking Works

1. **Player registers** - Publishes `player_registered` event to DHT
2. **Coordinator matches** - Leader proposes matches via `match_proposed`
3. **Players confirm** - Both confirm via `match_found`
4. **Host starts game** - Deterministically selected host starts GameServer
5. **State syncs** - 60 FPS state broadcast via DHT pub/sub

**Key insight:** Events are facts (past tense), not commands.
See [docs/architecture/SNAKE_DUEL_ARCHITECTURE.md](docs/architecture/SNAKE_DUEL_ARCHITECTURE.md)

---

## Documentation

### 📚 Start Here

- **[docs/README.md](docs/README.md)** - Documentation index
- **[docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md)** ⭐ - Complete architecture guide
  - Explains "mesh of meshes" vision
  - All abbreviations (HTTP/3, DHT, Raft, CRDT, mDNS)
  - When to use what (local cluster vs global mesh)
  - Scale limits and trade-offs

### 🏗️ Architecture

- [ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) - Main architecture doc
- [SNAKE_DUEL_ARCHITECTURE.md](docs/architecture/SNAKE_DUEL_ARCHITECTURE.md) - Game protocol
- [MESH_PATTERNS.md](docs/architecture/MESH_PATTERNS.md) - Distributed patterns
- [DHT_MATCHMAKING_IMPLEMENTATION.md](docs/architecture/DHT_MATCHMAKING_IMPLEMENTATION.md) - DHT details

### 🚀 Deployment

- [DEMO_DEPLOYMENT.md](docs/deployment/DEMO_DEPLOYMENT.md) - Production deployment
- [ENVIRONMENTS.md](docs/deployment/ENVIRONMENTS.md) - Docker comparison
- [docker/README.md](docker/README.md) - Docker environments overview

### 💻 Development

- [DEVELOPMENT.md](docs/development/DEVELOPMENT.md) - Dev setup
- [VERSION_SYNC.md](docs/development/VERSION_SYNC.md) - Version management
- [NEURAL_SNAKE_VISION.md](docs/development/NEURAL_SNAKE_VISION.md) - Future: AI snakes

---

## Project Structure

```
macula-arcade/
├── docker/                    # Docker environments
│   ├── demo/                  # Stable demo (Docker Hub)
│   ├── dev/                   # Development (hot-reload)
│   └── test/                  # Testing (local builds)
│
├── docs/                      # Documentation
│   ├── architecture/          # Design docs
│   ├── deployment/            # Deployment guides
│   └── development/           # Dev guides
│
├── system/                    # Elixir umbrella app
│   ├── apps/
│   │   ├── macula_arcade/     # Domain logic
│   │   │   ├── mesh.ex        # Macula connection
│   │   │   └── games/
│   │   │       ├── coordinator.ex
│   │   │       └── snake/game_server.ex
│   │   └── macula_arcade_web/ # Phoenix UI
│   │       └── live/snake_live.ex
│   ├── Dockerfile
│   └── mix.exs
│
└── README.md                  # This file
```

---

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| **Mesh** | Macula Platform | v0.10.0 |
| **Transport** | HTTP/3 (QUIC) | RFC 9114 |
| **Consensus** | Raft | Via macula |
| **State** | CRDTs (LWW-Register) | Via macula |
| **Backend** | Elixir + OTP | 1.17 + 27.1 |
| **Web** | Phoenix + LiveView | 1.8 |
| **Frontend** | HTML5 Canvas | Native |
| **Container** | Docker | Multi-stage |

---

## Snake Battle Royale

**Rules:**
- 🎯 2 players control snakes
- 🍎 Eat food to grow and score
- ⚠️ Avoid walls, your tail, opponent
- ⚔️ Head-to-head = draw (highest score wins)
- 🏆 Last snake alive wins

**Controls:**
- Arrow keys change direction
- No 180° turns allowed

**Grid:** 40x30 cells at 20 FPS

---

## Configuration

### Mesh Connection

Edit `system/apps/macula_arcade/lib/macula_arcade/mesh.ex`:

```elixir
@realm "macula.arcade.dev"
@presence_topic "arcade.node.presence"
```

### Game Settings

Edit `system/apps/macula_arcade/lib/macula_arcade/games/snake/game_server.ex`:

```elixir
@grid_width 40
@grid_height 30
@tick_interval 50  # ~20 FPS
@bot_enabled true  # AI controls both snakes
```

---

## Key Concepts

### Macula Platform Layer (v0.10.0)

Provides coordination primitives for workloads:

```elixir
# Register with platform
{:ok, info} = :macula.register_workload(client, %{
  workload_name: "macula_arcade",
  workload_type: "game_server"
})

# Query leader
{:ok, leader_id} = :macula.get_leader(client)

# Subscribe to leader changes
:macula.subscribe_leader_changes(client, callback)

# CRDTs for shared state
:macula.propose_crdt_update(client, "queue", player_list)
{:ok, value} = :macula.read_crdt(client, "queue")
```

**Scale:** Cluster-local (5-100 nodes, <50ms latency)

### DHT Pub/Sub

Global mesh messaging:

```elixir
# Publish event
:macula.publish(client, "arcade.snake.player_registered", %{
  player_id: id,
  node_id: node,
  timestamp: now
})

# Subscribe to events
{:ok, ref} = :macula.subscribe(client, "arcade.snake.match_found", callback)
```

**Scale:** Planet-wide (millions of nodes)

See [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) for when to use what.

---

## Common Questions

### Can this scale globally?

Yes! Macula uses a **"mesh of meshes"** architecture:

- **Local clusters** (5-100 nodes) use Raft + CRDTs for fast coordination
- **Global mesh** (millions of nodes) uses DHT pub/sub for eventual consistency
- Hybrid deployments get best of both worlds

See [ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) for details.

### What's the difference between demo/dev/test?

| Environment | Purpose | Ports | Image Source |
|-------------|---------|-------|--------------|
| **demo/** | Stable showcase | 4000-4003 | Docker Hub |
| **dev/** | Active development | 5000-5003 | Local build |
| **test/** | Testing unreleased | 4000-4003 | Local build |

See [docker/README.md](docker/README.md)

### How do I test Platform Layer features?

```bash
cd docker/test
./test.sh rebuild
./test.sh logs-gateway | grep "Leader"
```

See [docker/test/README.md](docker/test/README.md)

---

## Roadmap

### v0.3.0 - Multi-Game Support
- [ ] 4Pong (2-4 players, paddle per wall)
- [ ] Game lobbies and room selection
- [ ] Spectator mode

### v0.4.0 - Advanced Features
- [ ] Statistics and leaderboards
- [ ] Custom skins and themes
- [ ] Tournament brackets
- [ ] Voice chat (WebRTC)

### v0.5.0 - AI Evolution
- [ ] TWEANN (evolving neural networks)
- [ ] Genetic algorithms
- [ ] AI vs AI tournaments

See [NEURAL_SNAKE_VISION.md](docs/development/NEURAL_SNAKE_VISION.md)

---

## Contributing

1. Read [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md)
2. Set up dev environment: [docs/development/DEVELOPMENT.md](docs/development/DEVELOPMENT.md)
3. Check [docs/README.md](docs/README.md) for all guides
4. File issues: https://github.com/macula-io/macula-arcade/issues

---

## License

Apache 2.0

---

## Links

- **Macula Platform**: https://github.com/macula-io/macula
- **Phoenix Framework**: https://phoenixframework.org/
- **Phoenix LiveView**: https://hexdocs.pm/phoenix_live_view/
- **QUIC Protocol**: https://www.rfc-editor.org/rfc/rfc9000.html
- **Raft Consensus**: https://raft.github.io/
- **CRDTs**: https://crdt.tech/
