# Macula Arcade - Demo Deployment Guide

**Version:** v0.2.2-stable
**Last Updated:** 2025-01-21
**Purpose:** Stable deployment for demos and presentations

---

## Quick Start (Automated)

The easiest way to deploy for a demo:

```bash
cd /home/rl/work/github.com/macula-io/macula-arcade
./deploy-demo.sh
```

This script will:
1. ✅ Stop any existing containers
2. ✅ Clean up old images
3. ✅ Build fresh images with stable tags
4. ✅ Start all containers
5. ✅ Wait for health checks
6. ✅ Display access information

**Time:** ~1-2 minutes (pulls pre-built images from Docker Hub)

---

## Manual Deployment

If you prefer manual control:

### 1. Stop Existing Containers
```bash
docker compose -f docker-compose.demo.yml down
```

### 2. Pull Images from Docker Hub
```bash
docker compose -f docker-compose.demo.yml pull
```

### 3. Start Containers
```bash
docker compose -f docker-compose.demo.yml up -d
```

### 4. Check Status
```bash
docker compose -f docker-compose.demo.yml ps
```

---

## Access Points

Once deployed, access the arcade at:

| Service | URL | Purpose |
|---------|-----|---------|
| **Gateway** | http://localhost:4000 | Main entry point (bootstrap node) |
| **Peer 1** | http://localhost:4001 | Player node 1 |
| **Peer 2** | http://localhost:4002 | Player node 2 |
| **Bot Node** | http://localhost:4003 | Optional bot player |

### Health Endpoints

| Service | Health URL | Expected Response |
|---------|------------|-------------------|
| Gateway | http://localhost:8080/health | `{"status":"ok"}` |
| Peer 1 | http://localhost:8081/health | `{"status":"ok"}` |
| Peer 2 | http://localhost:8082/health | `{"status":"ok"}` |
| Bot Node | http://localhost:8083/health | `{"status":"ok"}` |

---

## Demo Scenarios

### Scenario 1: Two-Player Local Demo

**Setup:**
1. Open two browser windows
2. Window 1: http://localhost:4000 (Gateway)
3. Window 2: http://localhost:4001 (Peer 1)

**Demo Flow:**
1. Navigate to `/snake` on both windows
2. Click "Find Game" on both
3. Automatic matchmaking via Macula mesh
4. Play Snake Battle Royale!

**What to Show:**
- Mesh networking (no manual pairing needed)
- Real-time state synchronization
- 60 FPS gameplay
- Personality traits (asshole factor affects AI)

---

### Scenario 2: Multi-Peer Distributed Demo

**Setup:**
1. Open three browser windows
2. Window 1: http://localhost:4000 (Gateway)
3. Window 2: http://localhost:4001 (Peer 1)
4. Window 3: http://localhost:4002 (Peer 2)

**Demo Flow:**
1. Navigate to `/snake` on all three
2. First two to click "Find Game" get matched
3. Third window stays in waiting queue
4. After game ends, third player gets matched with winner

**What to Show:**
- Distributed matchmaking
- Peer-to-peer via DHT routing
- Automatic mesh formation
- Scalability to multiple nodes

---

### Scenario 3: Mesh Topology Visualization

**Setup:**
1. Gateway: http://localhost:4000
2. Check Macula health: http://localhost:8080/health

**Demo Flow:**
1. Show 4 containers running (gateway + 3 peers)
2. Explain Macula v0.8.5 always-on architecture
3. All nodes have full capabilities (no roles)
4. Bootstrap node (gateway) helps initial discovery
5. Peers communicate directly via QUIC/HTTP3

**What to Show:**
- Docker network topology
- Health check endpoints
- Mesh self-organization
- No central server bottleneck

---

## Troubleshooting

### Containers Won't Start

**Check:**
```bash
docker compose -f docker-compose.demo.yml logs
```

**Common Issues:**
- Port already in use (4000-4003, 8080-8083)
- Docker daemon not running
- Insufficient memory (need ~2GB)

**Fix:**
```bash
# Stop conflicting containers
docker ps -a | grep -E "4000|4001|4002|4003" | awk '{print $1}' | xargs docker stop

# Try deployment again
./deploy-demo.sh
```

---

### Health Checks Failing

**Check Individual Services:**
```bash
# Gateway
curl http://localhost:8080/health

# Peer 1
curl http://localhost:8081/health

# Peer 2
curl http://localhost:8082/health

# Bot
curl http://localhost:8083/health
```

**Expected:** All should return `{"status":"ok"}`

**If Failing:**
```bash
# Check logs
docker compose -f docker-compose.demo.yml logs arcade-gateway
docker compose -f docker-compose.demo.yml logs arcade-peer1

# Restart specific service
docker compose -f docker-compose.demo.yml restart arcade-gateway
```

---

### Matchmaking Not Working

**Symptoms:**
- Players stuck on "Waiting for opponent"
- "Find Game" button doesn't match players

**Debug:**
```bash
# Check mesh connectivity
docker compose -f docker-compose.demo.yml logs | grep -i "mesh\|dht\|bootstrap"

# Verify network
docker network inspect macula-arcade_arcade-mesh
```

**Fix:**
```bash
# Full restart with clean network
docker compose -f docker-compose.demo.yml down -v
./deploy-demo.sh
```

---

### Game Not Rendering

**Symptoms:**
- Blank screen after match found
- JavaScript errors in browser console

**Check:**
```bash
# Verify Phoenix is serving correctly
curl http://localhost:4000/snake
```

**Fix:**
- Hard refresh browser (Ctrl+Shift+R or Cmd+Shift+R)
- Clear browser cache
- Try different browser

---

## Monitoring During Demo

### Real-Time Logs

**All Services:**
```bash
docker compose -f docker-compose.demo.yml logs -f
```

**Specific Service:**
```bash
docker compose -f docker-compose.demo.yml logs -f arcade-gateway
docker compose -f docker-compose.demo.yml logs -f arcade-peer1
```

**Filter for Events:**
```bash
# Matchmaking events
docker compose -f docker-compose.demo.yml logs | grep -i "match\|queue"

# Game events
docker compose -f docker-compose.demo.yml logs | grep -i "game\|snake"

# Mesh events
docker compose -f docker-compose.demo.yml logs | grep -i "mesh\|quic\|dht"
```

---

### Container Status

```bash
# Summary
docker compose -f docker-compose.demo.yml ps

# Detailed
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

---

## Post-Demo Cleanup

### Keep Running
```bash
# Just leave it running for next demo
# Containers will auto-restart if Docker daemon restarts
```

### Stop Containers
```bash
docker compose -f docker-compose.demo.yml stop
```

### Full Cleanup
```bash
# Stop and remove containers, networks, volumes
docker compose -f docker-compose.demo.yml down -v

# Also remove images (for fresh rebuild next time)
docker images | grep macula-arcade | awk '{print $3}' | xargs docker rmi -f
```

---

## Demo Talking Points

### Technical Highlights

1. **Macula Mesh Networking**
   - HTTP/3 (QUIC) transport for NAT-friendly communication
   - Self-organizing peer-to-peer topology
   - DHT-based service discovery
   - No central server required after bootstrap

2. **Real-Time Game Engine**
   - 60 FPS game loop
   - Sub-50ms state synchronization
   - Phoenix LiveView for reactive UI
   - OTP supervision trees for fault tolerance

3. **Distributed Architecture**
   - Each container = autonomous node
   - Mesh handles routing and discovery
   - Scales to hundreds of nodes
   - Resilient to node failures

4. **Bot AI**
   - Heuristic AI with personality traits
   - asshole_factor (0-100) affects behavior
   - Flood-fill pathfinding
   - Strategic food competition
   - *Future: Neural network evolution (TWEANN)*

### Business Value

1. **Edge-First Design**
   - Runs on IoT devices, containers, edge servers
   - Reduces latency by local processing
   - No cloud dependency after bootstrap

2. **Scalability**
   - Linear scaling with node count
   - No bottlenecks or central coordinators
   - Mesh handles load distribution

3. **Developer Experience**
   - Single Docker command deployment
   - Auto-discovery, zero configuration
   - Observable via health endpoints
   - Phoenix LiveView for rapid UI development

---

## Technical Specifications

### Software Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Macula | v0.8.5 | HTTP/3 mesh networking |
| Elixir | 1.17.3 | Application runtime |
| Erlang/OTP | 27.1.2 | VM and concurrency |
| Phoenix | 1.8 | Web framework |
| LiveView | Latest | Real-time UI |

### Resource Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 2 cores | 4 cores |
| RAM | 2GB | 4GB |
| Disk | 500MB | 1GB |
| Network | 10 Mbps | 100 Mbps |

### Port Mapping

| Container | HTTP | QUIC (UDP) | Health |
|-----------|------|------------|--------|
| Gateway | 4000 | 4433 | 8080 |
| Peer 1 | 4001 | 4434 | 8081 |
| Peer 2 | 4002 | 4435 | 8082 |
| Bot 1 | 4003 | 4436 | 8083 |

---

## Version Information

**Release:** v0.2.2
**Docker Hub:** maculacid/macula-arcade:0.2.2
**Available Tags:** latest, 0.2, 0.2.2
**Docker Compose:** docker-compose.demo.yml
**Deployment Script:** deploy-demo.sh

**Known Working Configuration:**
- ✅ 4-node mesh (1 gateway + 3 peers)
- ✅ Snake Battle Royale (2-player PvP)
- ✅ Automatic matchmaking via DHT
- ✅ Real-time state sync via pub/sub
- ✅ Bot AI with personality traits
- ✅ Health monitoring endpoints

---

## Support

**Issues:** https://github.com/macula-io/macula-arcade/issues
**Documentation:** See README.md and architecture docs
**Logs:** `docker compose -f docker-compose.demo.yml logs`

---

**Ready for Demo!** 🎮
