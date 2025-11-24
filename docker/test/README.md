# Test Environment - Macula Arcade

**Purpose:** Test latest code from local macula + macula-arcade repositories

## What This Environment Does

This environment:
- ✅ Builds from **local source** (`../macula` + `../macula-arcade`)
- ✅ Tests **unreleased features** (Platform Layer v0.10.0)
- ✅ Uses **cache busting** for clean builds
- ✅ Creates **4-node mesh** (gateway + 2 peers + 1 bot)

## Features Tested

### Macula v0.10.0 (Platform Layer)
- **Raft Consensus** - Leader election across nodes
- **CRDTs** - Distributed shared state (LWW-Register)
- **DHT Pub/Sub** - Event-driven coordination
- **HTTP/3 (QUIC)** - Mesh networking

### Macula Arcade Features
- **Snake Duel Protocol v0.2.0** - Decentralized matchmaking
- **Leader-based coordination** - Using Platform Layer APIs
- **Cross-node gaming** - Games span multiple containers
- **Real-time state sync** - 60 FPS over mesh

## Quick Start

### 1. Build and Run
```bash
./test.sh rebuild
```

This will:
1. Stop any running containers
2. Build from scratch (no cache)
3. Start all 4 nodes
4. Wait for health checks

### 2. Open Web UI

- Gateway: http://localhost:4000
- Peer 1: http://localhost:4001
- Peer 2: http://localhost:4002
- Bot 1: http://localhost:4003 (headless)

### 3. Test Cross-Node Matchmaking

1. Open http://localhost:4001 in one browser
2. Click "Find Game"
3. Open http://localhost:4002 in another browser
4. Click "Find Game"
5. Watch them match across nodes!

## Available Commands

```bash
./test.sh build      # Build containers
./test.sh up         # Start containers
./test.sh down       # Stop containers
./test.sh rebuild    # Clean + build + start (recommended)
./test.sh logs       # Follow all logs
./test.sh clean      # Remove everything
```

### Specific Logs

```bash
./test.sh logs-gateway    # Gateway node only
./test.sh logs-peer1      # Peer 1 only
./test.sh logs-peer2      # Peer 2 only
./test.sh logs-bot        # Bot node only
```

## Architecture

### Mesh Topology

```
arcade-gateway (172.25.0.10)
  ├─ Bootstrap node (no MACULA_BOOTSTRAP_PEERS)
  ├─ Raft leader election
  └─ DHT bootstrap registry

arcade-peer1 (172.25.0.11)
  ├─ Connects to gateway
  ├─ Participates in Raft
  └─ Hosts games

arcade-peer2 (172.25.0.12)
  ├─ Connects to gateway
  ├─ Participates in Raft
  └─ Hosts games

arcade-bot1 (172.25.0.13)
  ├─ Connects to gateway
  ├─ Headless client
  └─ Auto-joins matchmaking (BOT_COUNT=0 currently)
```

### Ports

| Service | HTTP | Health | QUIC | IP |
|---------|------|--------|------|-------------|
| Gateway | 4000 | 8080 | 4433 | 172.25.0.10 |
| Peer 1  | 4001 | 8081 | 4434 | 172.25.0.11 |
| Peer 2  | 4002 | 8082 | 4435 | 172.25.0.12 |
| Bot 1   | 4003 | 8083 | 4436 | 172.25.0.13 |

### Environment Variables

Each node uses:
- `MACULA_QUIC_PORT`: QUIC listening port (4433-4436)
- `MACULA_REALM`: Isolation realm (`macula.arcade.dev`)
- `MACULA_BOOTSTRAP_PEERS`: Connect to gateway (peers only)
- `PORT`: Phoenix HTTP port (4000-4003)
- `PHX_HOST`: Phoenix hostname
- `SECRET_KEY_BASE`: Phoenix secret
- `DATABASE_PATH`: `:memory:` (no persistence)
- `BOT_COUNT`: Number of bot clients (0 = disabled)

## What Gets Tested

### Platform Layer APIs

```elixir
# Workload registration
{:ok, info} = :macula.register_workload(client, %{
  workload_name: "macula_arcade",
  workload_type: "game_server"
})

# Leader queries
{:ok, leader_node_id} = :macula.get_leader(client)

# Leader change subscriptions
:macula.subscribe_leader_changes(client, callback)

# CRDT operations
:ok = :macula.propose_crdt_update(client, "queue", player_list)
{:ok, value} = :macula.read_crdt(client, "queue")
```

### Mesh Networking

- HTTP/3 (QUIC) connections between nodes
- DHT pub/sub for game events
- mDNS local discovery (within Docker network)
- NAT traversal (via gateway relay)

### Game Protocol

- `arcade.snake.player_registered` - Player joins queue
- `arcade.snake.match_proposed` - Match suggestion
- `arcade.snake.match_found` - Both players confirmed
- `arcade.snake.game_started` - Game initialized
- `arcade.snake.state_updated` - 60 FPS game state

## Verification Checklist

After running `./test.sh rebuild`, verify:

### ✅ Mesh Connectivity
```bash
# Check gateway logs
./test.sh logs-gateway | grep "Connected"

# Should see:
# [Mesh] Connected to Macula platform
# [Mesh] Registered with Platform Layer
```

### ✅ Leader Election
```bash
# Check all node logs
./test.sh logs | grep "Leader"

# Should see:
# Current leader: <node_id>
# We are leader now: true/false
```

### ✅ DHT Pub/Sub
```bash
# Check peer logs
./test.sh logs-peer1 | grep "player_registered"

# Should see events when players register
```

### ✅ Cross-Node Games
1. Register player on peer1 (http://localhost:4001)
2. Register player on peer2 (http://localhost:4002)
3. Check logs - should see match proposal and game start

## Troubleshooting

### Build Fails

```bash
# Clean everything and rebuild
docker compose down -v --rmi all
./test.sh rebuild
```

### Containers Won't Start

```bash
# Check health
docker compose ps

# Check logs
./test.sh logs

# Common issue: port conflicts with demo environment
# Solution: Stop demo first
```

### Mesh Connection Issues

```bash
# Verify gateway is healthy
curl http://localhost:8080/health

# Check gateway logs for peer connections
./test.sh logs-gateway | grep "peer"
```

### Leader Election Not Working

Check that all nodes are in the same realm:
```bash
docker compose exec arcade-gateway env | grep MACULA_REALM
# Should be: macula.arcade.dev (same on all nodes)
```

## Development Workflow

### Testing Local Changes

1. Make changes to `macula-arcade` code
2. `./test.sh rebuild` - rebuilds with changes
3. Check logs for errors
4. Test in browser

### Testing Macula Changes

1. Make changes to `../macula` code
2. `./test.sh rebuild` - rebuilds with local macula
3. Verify Platform Layer features work

### Debugging

```bash
# Attach to running container
docker compose exec arcade-gateway bash

# Check Erlang processes
docker compose exec arcade-gateway bin/macula_arcade remote

# View config
docker compose exec arcade-gateway env
```

## Clean Up

### Stop Containers
```bash
./test.sh down
```

### Remove Everything
```bash
./test.sh clean
# Confirms before deleting volumes and images
```

## Further Reading

- Main architecture: `/ARCHITECTURE.md`
- Docker environments: `../README.md`
- Snake protocol: `/docs/SNAKE_DUEL_PROTOCOL.md`
- Platform Layer: `/home/rl/work/github.com/macula-io/macula/architecture/`
