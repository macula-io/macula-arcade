# Macula Arcade

A multiplayer browser-based arcade platform built on [Macula](https://github.com/macula-io/macula) HTTP/3 mesh networking.

## Features

- **Snake Battle Royale**: 2-player competitive snake game
- **Mesh Networking**: Players automatically discover each other via Macula
- **Real-time Multiplayer**: 60 FPS game loop with live state synchronization
- **Browser-Based**: No downloads, just run and play at `localhost:4000`
- **Containerized**: Single Docker container deployment

## Architecture

```
┌─────────────────────────────────────────────┐
│          Phoenix LiveView (Port 4000)       │
│  ┌────────────┐          ┌──────────────┐  │
│  │ Snake UI   │          │ Canvas Hook  │  │
│  └────────────┘          └──────────────┘  │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────┴──────────────────────────┐
│         Macula Mesh (QUIC/HTTP3)            │
│  ┌───────────┐  ┌─────────┐  ┌──────────┐  │
│  │ Node Mgr  │  │ Pub/Sub │  │ Discovery│  │
│  └───────────┘  └─────────┘  └──────────┘  │
└─────────────────────────────────────────────┘
                   │
┌──────────────────┴──────────────────────────┐
│          Game Engine (OTP/GenServer)        │
│  ┌────────────┐          ┌──────────────┐  │
│  │GameServer  │          │ Coordinator  │  │
│  │(60 FPS)    │          │(Matchmaking) │  │
│  └────────────┘          └──────────────┘  │
└─────────────────────────────────────────────┘
```

## Quick Start

### Using Docker

```bash
# Build the image
cd system
docker build -t macula-arcade:latest .

# Run instance 1
docker run -d -p 4000:4000 --name arcade1 macula-arcade:latest

# Run instance 2 (on another machine or different port)
docker run -d -p 4001:4000 --name arcade2 macula-arcade:latest

# Open browser
# Player 1: http://localhost:4000/snake
# Player 2: http://localhost:4001/snake (or another machine at :4000)
```

### Development Mode

```bash
cd system

# Install dependencies
mix deps.get
cd apps/macula_arcade_web/assets && npm install && cd -

# Run Phoenix server
mix phx.server

# Visit http://localhost:4000/snake
```

## How It Works

### Automatic Matchmaking

1. Player opens browser at `/snake`
2. Clicks "Find Game"
3. NodeManager publishes player presence on Macula mesh topic `arcade.matchmaking.snake`
4. Coordinator pairs 2 waiting players
5. GameServer starts, broadcasting state on `arcade.game.{game_id}.state`
6. Both players' LiveViews render game in real-time

### Mesh Discovery

Each container runs a Macula client that:
- Connects to mesh endpoint (`https://localhost:4433`)
- Publishes presence to mesh
- Discovers other nodes via Macula pub/sub
- Routes game events through the mesh

### Game State Synchronization

- GameServer runs at 60 FPS (16ms tick)
- State broadcasted via Macula pub/sub
- Player input sent via dedicated topics
- Canvas hook renders state in browser

## Games

### Snake Battle Royale

**Rules:**
- 2 players, each controls a snake
- Collect food to grow and score points
- Avoid walls, your own tail, and opponent's snake
- Head-to-head collision = draw
- Last snake alive wins

**Controls:**
- Arrow keys to change direction
- Cannot reverse direction (no 180° turns)

**Grid:** 40x30 cells

## Tech Stack

- **Backend**: Elixir 1.15 + OTP 26
- **Web**: Phoenix 1.8 + LiveView
- **Networking**: Macula v0.5.0 (HTTP/3 over QUIC)
- **Frontend**: HTML5 Canvas + JavaScript hooks
- **Containerization**: Docker multi-stage build

## Project Structure

```
macula-arcade/
├── system/
│   ├── apps/
│   │   ├── macula_arcade/          # Domain app
│   │   │   ├── lib/
│   │   │   │   ├── mesh/
│   │   │   │   │   └── node_manager.ex
│   │   │   │   └── games/
│   │   │   │       ├── coordinator.ex
│   │   │   │       └── snake/
│   │   │   │           └── game_server.ex
│   │   └── macula_arcade_web/      # Web app
│   │       ├── lib/
│   │       │   └── live/
│   │       │       └── snake_live.ex
│   │       └── assets/
│   │           └── js/
│   │               └── snake_canvas.js
│   ├── Dockerfile
│   └── mix.exs
└── README.md
```

## Configuration

### Macula Connection

Edit `apps/macula_arcade/lib/macula_arcade/mesh/node_manager.ex`:

```elixir
@realm "macula.arcade"
@mesh_url "https://localhost:4433"
```

### Game Settings

Edit `apps/macula_arcade/lib/macula_arcade/games/snake/game_server.ex`:

```elixir
@grid_width 40
@grid_height 30
@tick_interval 16  # ~60 FPS
```

## Publishing to Docker Hub

```bash
cd system

# Build
docker build -t yourusername/macula-arcade:latest .

# Tag
docker tag macula-arcade:latest yourusername/macula-arcade:0.1.0

# Push
docker push yourusername/macula-arcade:latest
docker push yourusername/macula-arcade:0.1.0
```

## Roadmap

- [ ] 4Pong (2-4 players, one paddle per wall)
- [ ] Spectator mode
- [ ] Game statistics and leaderboards
- [ ] Custom skins and themes
- [ ] Tournament mode
- [ ] Multiple game rooms
- [ ] Voice chat via WebRTC

## License

Apache 2.0

## Links

- [Macula Platform](https://github.com/macula-io/macula)
- [Phoenix Framework](https://phoenixframework.org/)
- [LiveView](https://hexdocs.pm/phoenix_live_view/)