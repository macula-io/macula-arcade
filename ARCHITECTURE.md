# Macula Arcade Architecture

**Interactive game demo showcasing Macula mesh networking capabilities**

---

## Table of Contents

1. [Overview](#overview)
2. [Key Concepts & Abbreviations](#key-concepts--abbreviations)
3. [Mesh Architecture: Local vs Global](#mesh-architecture-local-vs-global)
4. [Macula Platform Layers](#macula-platform-layers)
5. [Snake Duel Game Protocol](#snake-duel-game-protocol)
6. [When to Use What](#when-to-use-what)

---

## Overview

Macula Arcade demonstrates **distributed gaming** over a decentralized mesh network. It shows how applications can:

- Run across multiple nodes without a central server
- Coordinate game logic using mesh primitives
- Scale from local play to planet-scale deployment

**Current Features:**
- Snake Duel: 1v1 AI-controlled snake game
- Real-time state synchronization via mesh pub/sub
- Cross-node matchmaking
- Distributed game hosting

---

## Key Concepts & Abbreviations

### Core Networking Concepts

**HTTP/3 (QUIC)**
- **What**: Modern transport protocol built on UDP
- **Why**: NAT-friendly, firewall-friendly, low latency
- **Used for**: All Macula mesh communication
- **Scale**: Works globally across internet

**DHT (Distributed Hash Table)**
- **What**: Decentralized key-value store spread across nodes
- **Why**: No central server, self-organizing, resilient to failures
- **Used for**: Service discovery, pub/sub routing, player announcements
- **Scale**: Planet-scale (millions of nodes possible)

**Pub/Sub (Publish-Subscribe)**
- **What**: Messaging pattern where publishers send to topics, subscribers receive
- **Why**: Decouples senders from receivers, scales horizontally
- **Used for**: Game events (player_registered, match_found, game_started)
- **Scale**: Planet-scale via DHT routing

**mDNS (Multicast DNS)**
- **What**: Zero-config local network discovery using multicast
- **Why**: Finds nearby nodes without configuration
- **Used for**: Local peer discovery on LAN
- **Scale**: Local network only (single subnet)

**NAT Traversal**
- **What**: Techniques to connect peers behind firewalls/routers
- **Why**: Most home/office networks use NAT
- **Used for**: Connecting nodes across different networks
- **Scale**: Internet-wide connectivity

### Coordination Primitives (Platform Layer)

**Raft Consensus**
- **What**: Algorithm for distributed agreement (leader election, log replication)
- **Why**: Provides strong consistency in trusted clusters
- **Used for**: Leader election within a local cluster
- **Scale**: **Local cluster only** (5-7 nodes typical, requires low latency)
- **Latency requirement**: <50ms RTT between nodes

**CRDT (Conflict-Free Replicated Data Type)**
- **What**: Data structures that merge automatically without conflicts
- **Why**: Eventual consistency without coordination
- **Used for**: Shared state across cluster nodes (optional)
- **Scale**: **Local cluster** or **limited cross-cluster** (with eventual consistency)
- **Types**:
  - LWW-Register (Last-Write-Wins): Simple value with timestamp

**Platform Layer (v0.10.0+)**
- **What**: Optional coordination APIs for workloads
- **Why**: Simplifies common distributed patterns
- **Includes**: Leader election (Raft), shared state (CRDTs), discovery
- **Scale**: **Cluster-local** features for trusted environments

---

## Mesh Architecture: Local vs Global

### The "Mesh of Meshes" Model

```
                 Planet-Scale Macula Network
                           |
        +-----------------+------------------+
        |                 |                  |
  EU-West Cluster    US-East Cluster   Asia-Pacific Cluster
  (5-10 nodes)       (5-10 nodes)       (5-10 nodes)
        |                 |                  |
  Raft + CRDTs       Raft + CRDTs       Raft + CRDTs
  (local consensus)  (local consensus)  (local consensus)
        |                 |                  |
        +--------DHT Pub/Sub (global)-------+
                (eventual consistency)
```

### Local Cluster (Trusted Environment)

**Characteristics:**
- Low latency (<50ms RTT)
- Stable connections
- Trusted nodes (same datacenter, same organization)
- 5-100 nodes typical

**Available Features:**
- ✅ Raft consensus (leader election)
- ✅ CRDTs (shared state)
- ✅ DHT pub/sub (events)
- ✅ Strong consistency possible

**Use Cases:**
- Coordinated matchmaking within a region
- Shared game lobbies for a datacenter
- Load balancing across trusted servers

### Global Mesh (Untrusted/Internet-Scale)

**Characteristics:**
- High latency (100-500ms+ RTT)
- Unstable connections (mobile, WiFi)
- Untrusted nodes (players' home PCs)
- 1000s-millions of nodes

**Available Features:**
- ✅ DHT pub/sub (events)
- ✅ NAT traversal (gateway relay)
- ✅ mDNS (local discovery)
- ❌ **No Raft** (latency too high, quorum unreliable)
- ⚠️ **Limited CRDTs** (eventual consistency only)

**Use Cases:**
- Player-to-player game announcements
- Cross-region game discovery
- Decentralized matchmaking
- Peer-to-peer game hosting

---

## Macula Platform Layers

Macula provides **three architectural layers**:

### 1. Transport Layer (Always Available)

**HTTP/3 (QUIC) mesh networking**
- Peer-to-peer connections
- NAT traversal via gateway relay
- TLS encryption built-in
- Low latency, multiplexed streams

**Scale:** Planet-scale ✅

### 2. Mesh Layer (Always Available)

**DHT pub/sub and service discovery**
- Topic-based publish-subscribe
- Service advertisement and discovery
- Realm isolation (multi-tenancy)
- Event-driven coordination

**Scale:** Planet-scale ✅

### 3. Platform Layer (Optional, v0.10.0+)

**Coordination primitives for clusters**
- `register_workload()` - Register with platform
- `get_leader()` - Query Raft leader
- `subscribe_leader_changes()` - Leadership notifications
- `propose_crdt_update()` - Update shared state
- `read_crdt()` - Read shared state

**Scale:** Cluster-local (5-100 nodes) ⚠️

**When to use:**
- ✅ Local cluster with low latency
- ✅ Trusted environment (same org)
- ✅ Need strong consistency
- ❌ **Not for planet-scale coordination**
- ❌ **Not for untrusted nodes**

---

## Snake Duel Game Protocol

### Protocol v0.2.0 (Current)

**Design Philosophy:**
- Event-driven (not RPC-heavy)
- Decentralized (no coordinator required)
- Works at both local and global scale

### Event Flow

```
Player A (Node 1)          DHT Pub/Sub          Player B (Node 2)
     |                          |                      |
     |--player_registered------>|                      |
     |                          |---player_registered->|
     |                          |<-player_registered---|
     |<--player_registered------|                      |
     |                          |                      |
     |--match_proposed--------->|                      |
     |                          |---match_proposed---->|
     |                          |<-match_found---------|
     |<--match_found------------|                      |
     |                          |                      |
   (Host)                       |                   (Guest)
     |--game_started----------->|                      |
     |                          |---game_started------>|
     |                          |                      |
     |--state_updated---------->|                      |
     |                          |---state_updated----->|
     |  (60 FPS broadcast)      |                      |
```

### Event Topics (Past Tense - Facts)

- `arcade.snake.player_registered` - Player joined queue
- `arcade.snake.player_unregistered` - Player left queue
- `arcade.snake.match_proposed` - Match suggestion made
- `arcade.snake.match_found` - Both players confirmed
- `arcade.snake.game_started` - Game initialized
- `arcade.snake.game_ended` - Game finished

### RPC Procedures (Imperative - Commands)

- `arcade.snake.register_player` - Join matchmaking queue
- `arcade.snake.find_opponents` - Query available players
- `arcade.snake.submit_action` - Submit player input

### Key Design Decisions

**Events over State Sync:**
- Events describe "what happened" (business-meaningful)
- Not CRUD (Created/Updated/Deleted)
- Enables event sourcing and audit trails

**IDs in Payloads, Not Topics:**
- ❌ Bad: `arcade.game.{game_id}.state` (1M games = 1M topics)
- ✅ Good: `arcade.game.state` with `{game_id: "..."}` in payload
- Prevents topic explosion at scale

**Deterministic Match IDs:**
- Hash of sorted player IDs
- Same players = same match ID (idempotent)
- Prevents duplicate matches

**Host Selection:**
- Deterministic: lowest node_id becomes host
- No coordination needed
- Guest receives state via DHT pub/sub

---

## When to Use What

### Local Cluster Game Hosting (Current Implementation)

**Scenario:** 5 game servers in a datacenter

**Architecture:**
```
Game Server 1 (Leader)  ─┐
Game Server 2           ─┤ Raft Cluster
Game Server 3           ─┤ (local coordination)
Game Server 4           ─┤
Game Server 5 (Follower)─┘
         |
    DHT Pub/Sub
         |
   Player Clients
```

**Use:**
- ✅ Platform Layer (Raft + CRDTs)
- ✅ Leader coordinates matchmaking
- ✅ CRDTs for global queue state
- ✅ DHT pub/sub for game events

**Benefits:**
- Centralized matchmaking (faster)
- Strong consistency guarantees
- Easier debugging

### Planet-Scale P2P Gaming (Future Vision)

**Scenario:** 10,000 players across the world

**Architecture:**
```
Region: EU-West          Region: US-East         Region: Asia-Pacific
Players 1-3000           Players 3001-6000       Players 6001-10000
      |                        |                         |
      +-------------- DHT Pub/Sub (global) -------------+
                   (eventual consistency)
```

**Use:**
- ✅ DHT pub/sub only
- ✅ NAT traversal
- ❌ **No Raft** (too much latency)
- ❌ **No centralized matchmaking**

**Pattern:**
- Players publish `player_registered` globally
- Any player can propose matches
- DHT delivers events to interested parties
- Games hosted P2P (player becomes host)

**Benefits:**
- True decentralization
- Resilient to node failures
- Scales to millions

### Hybrid: Regional Clusters + Global Mesh

**Scenario:** Professional esports platform

**Architecture:**
```
EU Cluster (Raft)      US Cluster (Raft)      Asia Cluster (Raft)
 (Fast local games)     (Fast local games)      (Fast local games)
      |                       |                        |
      +----------- DHT Pub/Sub (cross-region) --------+
              (Tournament announcements)
```

**Use:**
- ✅ Platform Layer **within each cluster**
- ✅ DHT pub/sub **across clusters**
- ✅ Fast matchmaking locally (Raft)
- ✅ Discovery globally (DHT)

**Benefits:**
- Best of both worlds
- Low latency for most players
- Global discovery and tournaments

---

## Current Status (v0.10.0)

**Implemented:**
- ✅ HTTP/3 mesh connectivity
- ✅ DHT pub/sub for game events
- ✅ Platform Layer APIs (Raft + CRDTs)
- ✅ Snake Duel protocol v0.2.0
- ✅ Local matchmaking
- ✅ Cross-node game coordination

**Architecture Choice:**
- **Local cluster mode** (using Platform Layer)
- Suitable for: datacenter deployment, trusted nodes, <100 nodes
- Leader-based matchmaking for consistency

**Future Evolution:**
- Add P2P mode (pure DHT, no Platform Layer)
- NAT traversal improvements
- Cross-cluster federation
- Mobile client support

---

## Decision Guide

### Should I use Platform Layer (Raft/CRDTs)?

**YES if:**
- ✅ Cluster has <100 nodes
- ✅ Nodes are in same datacenter (low latency)
- ✅ Nodes are trusted (same organization)
- ✅ You need strong consistency
- ✅ You want centralized coordination

**NO if:**
- ❌ Nodes are globally distributed
- ❌ High latency between nodes (>50ms)
- ❌ Nodes are untrusted (player devices)
- ❌ You want pure decentralization
- ❌ You need to scale to 1000s+ nodes

### Should I use pure DHT pub/sub?

**YES if:**
- ✅ Planet-scale deployment
- ✅ Untrusted nodes (player devices)
- ✅ High latency acceptable
- ✅ Eventual consistency is fine
- ✅ P2P architecture desired

**NO if:**
- ❌ Need strong consistency
- ❌ Need centralized coordination
- ❌ Small trusted cluster (<50 nodes)

---

## Further Reading

- **Macula Architecture Docs**: `/home/rl/work/github.com/macula-io/macula/architecture/`
- **WAMP Protocol** (legacy reference): Influenced event naming conventions
- **Raft Consensus**: https://raft.github.io/
- **CRDTs**: https://crdt.tech/
- **DHT**: Kademlia algorithm (used by BitTorrent, IPFS)
- **QUIC**: https://www.rfc-editor.org/rfc/rfc9000.html

---

## Questions?

This architecture balances **pragmatism** (clusters for performance) with **vision** (global mesh scaling).

The key insight: **"Mesh of meshes"** - small clusters with strong coordination, connected by eventual-consistency mesh.
