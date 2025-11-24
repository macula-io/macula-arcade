# Production Environment - Macula Arcade

**Purpose:** Production deployment using optimized Docker images

## Overview

This environment uses `Dockerfile.prod` which is optimized for production:
- Debian Bookworm Slim (smaller, more secure)
- Runtime certificate generation
- Health checks configured
- Multi-architecture support (amd64/arm64)

## Quick Start

### Deploy
```bash
./deploy.sh deploy
```

This will:
1. Stop any running containers
2. Build from scratch (no cache)
3. Start all 4 nodes
4. Wait for health checks

### Access Web UI

- Gateway: http://localhost:4000
- Peer 1: http://localhost:4001
- Peer 2: http://localhost:4002
- Bot 1: http://localhost:4003 (headless)

## Available Commands

```bash
./deploy.sh build      # Build production images
./deploy.sh up         # Start containers
./deploy.sh down       # Stop containers
./deploy.sh deploy     # Clean + build + start (recommended)
./deploy.sh logs       # Follow all logs
./deploy.sh clean      # Remove everything
```

### Specific Logs

```bash
./deploy.sh logs-gateway    # Gateway node only
./deploy.sh logs-peer1      # Peer 1 only
./deploy.sh logs-peer2      # Peer 2 only
./deploy.sh logs-bot        # Bot node only
```

## Production Features

### Using Dockerfile.prod

This environment uses `system/Dockerfile.prod` which includes:

1. **Optimized Base Image** - Debian Bookworm Slim (~20% smaller)
2. **Runtime Certificates** - Generated via docker-entrypoint.sh
3. **Health Checks** - Built-in HEALTHCHECK directive
4. **Multi-Architecture** - Supports amd64 and arm64

See `../../system/DOCKER.md` for complete comparison.

## Differences from Other Environments

| Feature | Dev | Demo | **Prod** |
|---------|-----|------|----------|
| **Dockerfile** | Dockerfile | - | **Dockerfile.prod** |
| **Image Source** | Local build | Docker Hub | **Local build** |
| **Base Image** | Ubuntu 22.04 | - | **Debian Slim** |
| **Certificates** | Pre-built | - | **Runtime generated** |
| **Ports** | 5000-5003 | 4000-4003 | **4000-4003** |
| **Use Case** | Development | Showcase | **Production** |

## Further Reading

- Dockerfile comparison: `../../system/DOCKER.md`
- Docker environments: `../README.md`
- Main architecture: `../../docs/architecture/ARCHITECTURE.md`
