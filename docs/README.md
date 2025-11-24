# Macula Arcade Documentation

Complete documentation for the Macula Arcade interactive game demo.

## 📋 Quick Navigation

### For First-Time Users
1. Start here: [README.md](../README.md) - Project overview
2. Then read: [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md) - How it all works
3. Try it: [deployment/DEMO_DEPLOYMENT.md](deployment/DEMO_DEPLOYMENT.md) - Run the demo

### For Developers
1. Setup: [development/DEVELOPMENT.md](development/DEVELOPMENT.md) - Dev environment
2. Architecture: [architecture/](architecture/) - Technical deep-dives
3. Deploy: [deployment/](deployment/) - Docker environments

---

## 📚 Documentation Structure

### architecture/
Technical architecture and design documents

- **[ARCHITECTURE.md](architecture/ARCHITECTURE.md)** ⭐ **START HERE**
  - Complete system architecture
  - "Mesh of meshes" explained
  - All concepts and abbreviations (HTTP/3, DHT, Raft, CRDT, etc.)
  - When to use what (decision guide)
  - Scale limits and trade-offs

- **[SNAKE_DUEL_ARCHITECTURE.md](architecture/SNAKE_DUEL_ARCHITECTURE.md)**
  - Snake Duel Protocol v0.2.0
  - Event-driven coordination
  - Cross-node matchmaking
  - Deterministic host selection

- **[DHT_MATCHMAKING_IMPLEMENTATION.md](architecture/DHT_MATCHMAKING_IMPLEMENTATION.md)**
  - DHT-based matchmaking details
  - Event flow diagrams
  - Topic design patterns

- **[MESH_PATTERNS.md](architecture/MESH_PATTERNS.md)**
  - Common mesh networking patterns
  - Pub/sub best practices
  - Distributed coordination strategies

### deployment/
Docker environments and deployment guides

- **[DEMO_DEPLOYMENT.md](deployment/DEMO_DEPLOYMENT.md)**
  - Quick demo setup (pre-built images)
  - Production deployment
  - Troubleshooting

- **[ENVIRONMENTS.md](deployment/ENVIRONMENTS.md)**
  - Docker environment comparison
  - Demo vs Dev vs Test
  - Port assignments

- **[DOCKERHUB_README.md](deployment/DOCKERHUB_README.md)**
  - Docker Hub image documentation
  - Published versions
  - Usage instructions

### development/
Development guides and advanced features

- **[DEVELOPMENT.md](development/DEVELOPMENT.md)**
  - Local development setup
  - Hot-reload configuration
  - Testing strategies

- **[VERSION_SYNC.md](development/VERSION_SYNC.md)**
  - Version management
  - Macula version dependencies
  - Release process

- **[NEURAL_SNAKE_VISION.md](development/NEURAL_SNAKE_VISION.md)**
  - Future: Neural network AI snakes
  - TWEANN (Topology and Weight Evolving Artificial Neural Networks)
  - Evolution strategy

---

## 🗂️ Related Documentation

### Docker Environments
Each Docker environment has its own README:

- [../docker/README.md](../docker/README.md) - Environment overview
- [../docker/demo/](../docker/demo/) - Stable demo (Docker Hub images)
- [../docker/dev/](../docker/dev/) - Development environment
- [../docker/prod/README.md](../docker/prod/README.md) - Production environment (local builds)

### Macula Platform
Core platform documentation (in macula repo):

- `/home/rl/work/github.com/macula-io/macula/architecture/` - Platform architecture
- `macula/architecture/WORKLOAD_PLATFORM_API.md` - Platform Layer v0.10.0 APIs

---

## 🎯 Common Questions

### How do I run the demo?
See [deployment/DEMO_DEPLOYMENT.md](deployment/DEMO_DEPLOYMENT.md)

### How does the mesh work?
See [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md)

### Can this scale globally?
Yes! See the "Mesh Architecture: Local vs Global" section in [ARCHITECTURE.md](architecture/ARCHITECTURE.md)

### What's the difference between DHT and Raft?
- **DHT**: Planet-scale eventual consistency (millions of nodes)
- **Raft**: Cluster-local strong consistency (5-100 nodes)

See [ARCHITECTURE.md](architecture/ARCHITECTURE.md) for details.

### How do I develop locally?
See [development/DEVELOPMENT.md](development/DEVELOPMENT.md)

### What's the Snake Duel protocol?
See [architecture/SNAKE_DUEL_ARCHITECTURE.md](architecture/SNAKE_DUEL_ARCHITECTURE.md)

---

## 📖 Reading Path by Role

### 🎮 Game Developer
Wants to build games on Macula mesh

1. [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md) - Understand the platform
2. [architecture/SNAKE_DUEL_ARCHITECTURE.md](architecture/SNAKE_DUEL_ARCHITECTURE.md) - Learn the protocol
3. [development/DEVELOPMENT.md](development/DEVELOPMENT.md) - Set up dev environment
4. Start coding!

### 🏗️ Platform Developer
Wants to contribute to Macula

1. [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md) - Platform overview
2. [architecture/MESH_PATTERNS.md](architecture/MESH_PATTERNS.md) - Patterns and best practices
3. Macula repo: `/home/rl/work/github.com/macula-io/macula/architecture/`

### 🚀 DevOps Engineer
Wants to deploy Macula Arcade

1. [deployment/DEMO_DEPLOYMENT.md](deployment/DEMO_DEPLOYMENT.md) - Quick start
2. [deployment/ENVIRONMENTS.md](deployment/ENVIRONMENTS.md) - Environment options
3. [../docker/README.md](../docker/README.md) - Docker details

### 🧪 QA / Tester
Wants to test features

1. [../docker/prod/README.md](../docker/prod/README.md) - Test environment
2. [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md) - What to test
3. Test!

---

## 🔄 Document Status

| Document | Status | Last Updated | Notes |
|----------|--------|--------------|-------|
| ARCHITECTURE.md | ✅ Current | 2025-11-24 | Platform Layer v0.10.0 |
| SNAKE_DUEL_ARCHITECTURE.md | ✅ Current | 2025-11-17 | Protocol v0.2.0 |
| DEVELOPMENT.md | ⚠️ Needs update | 2025-11-21 | Update for v0.10.0 |
| DEMO_DEPLOYMENT.md | ⚠️ Needs update | 2025-11-21 | Update for v0.10.0 |
| DHT_MATCHMAKING_IMPLEMENTATION.md | ✅ Current | 2025-11-17 | Still relevant |
| MESH_PATTERNS.md | ✅ Current | 2025-11-15 | Timeless patterns |
| NEURAL_SNAKE_VISION.md | 🔮 Future | 2025-11-21 | Not yet implemented |

---

## 💡 Contributing

When adding new documentation:

1. **Choose the right directory**:
   - `architecture/` - How it works
   - `deployment/` - How to run it
   - `development/` - How to build it

2. **Update this index** - Add your new doc to the relevant section

3. **Cross-reference** - Link to related docs

4. **Keep it current** - Update the status table above

---

## 🆘 Need Help?

- Check the README in each directory
- Look for `🆘 Troubleshooting` sections in guides
- Review [ARCHITECTURE.md](architecture/ARCHITECTURE.md) decision guide
- File an issue: https://github.com/macula-io/macula-arcade/issues
