# Macula Arcade Docker Environments

Three environments for different use cases: development, demonstration, and production.

## Environments

### 🔧 dev/ - Development Environment

**Purpose:** Local development with hot-reload

**Use when:**
- You're actively developing macula-arcade
- You want to test changes without rebuilding
- You need to run alongside demo for comparison

**Ports:** 5000-5003 (HTTP), 9080-9083 (Health), 5433-5436 (QUIC)

**Quick start:**
```bash
cd dev
./deploy-dev.sh
```

**Features:**
- Local builds from `system/`
- Uses `Dockerfile` (development variant)
- Ubuntu 22.04 base
- Pre-built certificates
- Separate ports to avoid conflicts

---

### 📦 demo/ - Demonstration Environment

**Purpose:** Stable showcase using Docker Hub images

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

**Features:**
- Pre-built images from Docker Hub
- No local compilation required
- Stable released versions
- Standard ports

---

### 🚀 prod/ - Production Environment

**Purpose:** Production deployment with optimized images

**Use when:**
- You're deploying to cloud/k8s
- You need production-optimized images
- You want runtime certificate generation
- You need health checks for orchestration

**Ports:** 4000-4003 (HTTP), 8080-8083 (Health), 4433-4436 (QUIC)

**Quick start:**
```bash
cd prod
./deploy.sh deploy
```

**Features:**
- Uses `Dockerfile.prod` (production variant)
- Debian Bookworm Slim (~20% smaller)
- Runtime certificate generation
- Built-in health checks
- Multi-architecture support

---

## Environment Comparison

| Feature | Dev | Demo | Prod |
|---------|-----|------|------|
| **Purpose** | Development | Showcase | Production |
| **Image Source** | Local build | Docker Hub | Local build |
| **Dockerfile** | Dockerfile | (Docker Hub) | Dockerfile.prod |
| **Base Image** | Ubuntu 22.04 | Ubuntu 22.04 | Debian Slim |
| **Build Time** | Fast | None | Medium |
| **Certificates** | Pre-built | Pre-built | Runtime |
| **Health Checks** | docker-compose | docker-compose | Built-in |
| **Hot Reload** | ✅ Yes | ❌ No | ❌ No |
| **Ports** | 5000-5003 | 4000-4003 | 4000-4003 |
| **Use Case** | Active dev | Quick demo | Deploy to cloud |

---

## Port Allocation

### Dev Environment (5000-5003)
- Gateway: 5000 (HTTP), 5433 (QUIC), 9080 (Health)
- Peer 1: 5001 (HTTP), 5434 (QUIC), 9081 (Health)
- Peer 2: 5002 (HTTP), 5435 (QUIC), 9082 (Health)
- Bot 1: 5003 (HTTP), 5436 (QUIC), 9083 (Health)

### Demo/Prod Environments (4000-4003)
- Gateway: 4000 (HTTP), 4433 (QUIC), 8080 (Health)
- Peer 1: 4001 (HTTP), 4434 (QUIC), 8081 (Health)
- Peer 2: 4002 (HTTP), 4435 (QUIC), 8082 (Health)
- Bot 1: 4003 (HTTP), 4436 (QUIC), 8083 (Health)

**Note:** Demo and Prod use the same ports. Only run one at a time!

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
- Others connect via MACULA_BOOTSTRAP_PEERS
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
# Dev
cd dev && ./deploy-dev.sh

# Demo
cd demo && ./deploy-demo.sh

# Prod
cd prod && ./deploy.sh deploy
```

### Access Web UI
- **Dev:** http://localhost:5000 (gateway), 5001-5003 (peers)
- **Demo/Prod:** http://localhost:4000 (gateway), 4001-4003 (peers)

---

## Troubleshooting

### Port Conflicts
Demo and prod use the same ports (4000-4003).
Dev uses different ports (5000-5003) to avoid conflicts.

**Solution:** Stop one environment before starting another.

### Containers Won't Start
```bash
# Check logs
docker compose logs

# Clean and rebuild
docker compose down -v
docker compose up --build
```

### Mesh Connection Issues
Check that:
1. Gateway started first and is healthy
2. MACULA_BOOTSTRAP_PEERS points to gateway
3. QUIC ports (4433-4436) are not blocked

---

## Dockerfile Comparison

Two Dockerfiles serve different purposes:

**system/Dockerfile** (Dev)
- Ubuntu 22.04 base
- Pre-built certificates from `priv/certs/`
- Direct CMD start (no entrypoint)
- Faster iteration

**system/Dockerfile.prod** (Prod)
- Debian Bookworm Slim (smaller)
- Runtime certificate generation
- HEALTHCHECK directive
- Optimized for cloud/k8s

See `../system/DOCKER.md` for detailed comparison.

---

## Further Reading

- **System docs:** `../docs/`
- **Architecture:** `../docs/architecture/ARCHITECTURE.md`
- **Dockerfile comparison:** `../system/DOCKER.md`
- **Snake protocol:** `../docs/architecture/SNAKE_DUEL_ARCHITECTURE.md`
- **Deployment:** `../docs/deployment/`
