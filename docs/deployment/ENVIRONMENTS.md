# Macula Arcade - Environment Overview

Quick reference for managing demo and development environments.

---

## Two Environments

### 🎯 **DEMO** (Stable for Presentations)
- **Ports:** 4000-4003 (HTTP), 4433-4436 (QUIC), 8080-8083 (Health)
- **Version:** v0.2.2-stable
- **Purpose:** Stable demos, presentations, customer showcases
- **Deploy:** `./deploy-demo.sh`
- **Config:** `docker-compose.demo.yml`

### 🔧 **DEV** (Active Development)
- **Ports:** 5000-5003 (HTTP), 5433-5436 (QUIC), 9080-9083 (Health)
- **Version:** dev (from local `./system/` code)
- **Purpose:** Active coding, testing, neural integration
- **Deploy:** `./deploy-dev.sh`
- **Config:** `docker-compose.dev.yml`

---

## Quick Commands

### Deploy Demo (for presentation tomorrow)
```bash
./deploy-demo.sh
# Access: http://localhost:4000
```

### Deploy Dev (for neural work)
```bash
./deploy-dev.sh
# Access: http://localhost:5000
```

### Run Both Simultaneously
```bash
# Demo on 4000+ (containers: arcade-demo-*)
./deploy-demo.sh

# Dev on 5000+ (containers: dev-*)
./deploy-dev.sh

# Check both running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Stop Demo (Keep Dev)
```bash
docker compose -f docker-compose.demo.yml down
```

### Stop Dev (Keep Demo)
```bash
docker compose -f docker-compose.dev.yml down
```

### Stop Everything
```bash
docker compose -f docker-compose.demo.yml down
docker compose -f docker-compose.dev.yml down
```

---

## Environment Comparison

| Feature | DEMO | DEV |
|---------|------|-----|
| **Purpose** | Stable presentations | Active development |
| **HTTP Ports** | 4000-4003 | 5000-5003 |
| **QUIC Ports** | 4433-4436 | 5433-5436 |
| **Health Ports** | 8080-8083 | 9080-9083 |
| **Network** | 172.25.0.0/24 | 172.26.0.0/24 |
| **Realm** | macula.arcade | macula.arcade.dev |
| **Source** | Tagged v0.2.2-stable | Local ./system/ |
| **Logging** | INFO | DEBUG |
| **Rebuild** | Rare | Frequent |

---

## Typical Workflow

### Morning (Demo Day)
```bash
# Ensure demo is fresh
./deploy-demo.sh

# Test: http://localhost:4000
# Ready for presentation!
```

### Afternoon (Development)
```bash
# Start dev environment
./deploy-dev.sh

# Edit code in ./system/
vim system/apps/macula_arcade/lib/...

# Rebuild and test
docker compose -f docker-compose.dev.yml up --build -d

# Test: http://localhost:5000
```

### Both Running
```bash
# Demo for stakeholders at 4000
# Dev for yourself at 5000
# No conflicts!
```

---

## Port Reference Card

| Service | Demo Port | Dev Port |
|---------|-----------|----------|
| Gateway HTTP | 4000 | 5000 |
| Peer 1 HTTP | 4001 | 5001 |
| Peer 2 HTTP | 4002 | 5002 |
| Bot HTTP | 4003 | 5003 |
| Gateway Health | 8080 | 9080 |
| Peer 1 Health | 8081 | 9081 |
| Peer 2 Health | 8082 | 9082 |
| Bot Health | 8083 | 9083 |
| Gateway QUIC | 4433 | 5433 |
| Peer 1 QUIC | 4434 | 5434 |
| Peer 2 QUIC | 4435 | 5435 |
| Bot QUIC | 4436 | 5436 |

---

## Health Check URLs

### Demo
- http://localhost:8080/health (Gateway)
- http://localhost:8081/health (Peer 1)
- http://localhost:8082/health (Peer 2)
- http://localhost:8083/health (Bot)

### Dev
- http://localhost:9080/health (Gateway)
- http://localhost:9081/health (Peer 1)
- http://localhost:9082/health (Peer 2)
- http://localhost:9083/health (Bot)

---

## Documentation

- **DEMO_DEPLOYMENT.md** - Complete demo guide
- **DEVELOPMENT.md** - Complete dev guide
- **README.md** - Project overview
- **NEURAL_SNAKE_VISION.md** - Neural roadmap

---

## Current Status

Check what's running:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

---

**Ready to code!** 🚀
