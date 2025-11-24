# Macula Arcade Docker Environments

This directory contains different Docker Compose configurations for various use cases.

## Environments

### 📦 demo/ - Stable Demo (Pre-built Images)

**Purpose:** Run the stable demo using pre-built images from Docker Hub

**Use when:**
- You want to quickly demo macula-arcade
- You don't need to modify code
- You want a stable, tested version

**Ports:** 4000-4003 (HTTP), 8080-8083 (Health), 4433-4436 (QUIC)

**Quick start:**
```bash
cd demo
./deploy-demo.sh
```

---

### 🔧 dev/ - Development Environment

**Purpose:** Local development with hot-reload, separate from demo

**Use when:**
- You're actively developing macula-arcade
- You want to keep the stable demo running
- You need different ports to avoid conflicts

**Ports:** 5000-5003 (HTTP), 9080-9083 (Health), 5433-5436 (QUIC)

**Quick start:**
```bash
cd dev
./deploy-dev.sh
```

---

### 🧪 test/ - Testing Environment (Latest Code)

**Purpose:** Test latest changes from local macula + macula-arcade repos

**Use when:**
- You're testing mesh features (Platform Layer, DHT, etc.)
- You need to verify changes before publishing
- You're developing against unreleased macula versions

**Ports:** 4000-4003 (HTTP), 8080-8083 (Health), 4433-4436 (QUIC)

**Quick start:**
```bash
cd test
./test.sh rebuild
```

---

## Architecture Comparison

| Feature | Demo | Dev | Test |
|---------|------|-----|------|
| **Image Source** | Docker Hub | Local build | Local build |
| **Macula Version** | Published (v0.8.x) | Published | **Local repo** |
| **Hot Reload** | ❌ No | ✅ Yes | ❌ No |
| **Stability** | ✅ Stable | ⚠️ Dev code | ⚠️ Latest code |
| **Ports** | 4000-4003 | 5000-5003 | 4000-4003 |
| **Purpose** | Showcase | Development | Testing |

---

## Common Tasks

### View Logs
```bash
# All containers
docker compose logs -f

# Specific container
docker compose logs -f arcade-gateway
docker compose logs -f arcade-peer1
```

### Stop Everything
```bash
docker compose down
```

### Clean Rebuild
```bash
# Demo
cd demo && ./deploy-demo.sh

# Dev
cd dev && ./deploy-dev.sh

# Test
cd test && ./test.sh rebuild
```

### Access Web UI
- **Gateway:** http://localhost:4000 (or 5000 for dev)
- **Peer 1:** http://localhost:4001 (or 5001 for dev)
- **Peer 2:** http://localhost:4002 (or 5002 for dev)

---

## Network Architecture

All environments create a 4-node mesh:

```
arcade-gateway (Bootstrap)
    ├── arcade-peer1
    ├── arcade-peer2
    └── arcade-bot1 (Headless)
```

**Bootstrap Node:**
- First node in mesh
- Others connect to it via MACULA_BOOTSTRAP_PEERS
- Runs Raft leader election

**Peer Nodes:**
- Join mesh via bootstrap node
- Participate in DHT pub/sub
- Can host games

**Bot Node:**
- Headless client (no browser needed)
- Used for scalability testing
- Can auto-join matchmaking

---

## Troubleshooting

### Containers won't start
```bash
# Check logs
docker compose logs

# Clean and rebuild
docker compose down -v
docker compose up --build
```

### Port conflicts
Demo and test use the same ports (4000-4003).
Dev uses different ports (5000-5003) to avoid conflicts.

Make sure only one environment is running at a time, or use dev for parallel testing.

### Mesh connection issues
Check that:
1. Gateway started first and is healthy
2. MACULA_BOOTSTRAP_PEERS points to gateway
3. QUIC ports (4433-4436) are not blocked

### Need latest macula changes
Use the **test/** environment - it builds from `../macula` directory.

---

## Further Reading

- Main docs: `/ARCHITECTURE.md` - Full architecture explanation
- Macula docs: `/home/rl/work/github.com/macula-io/macula/architecture/`
- Snake protocol: `docs/SNAKE_DUEL_PROTOCOL.md`
