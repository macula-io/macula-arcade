# Macula Arcade v0.2.0 Roadmap

## Overview

Version 0.2.0 implements the complete Snake Duel game with decentralized matchmaking over the Macula mesh network. This version serves as a demonstration of Macula's distributed pub/sub and RPC capabilities.

## Goals

1. **Functional Snake Duel game** - Playable 1v1 competitive snake
2. **Decentralized matchmaking** - No central coordinator
3. **Cross-peer gameplay** - Players on different nodes can compete
4. **Protocol validation** - Prove the Snake Duel Protocol works

## Prerequisites

- Macula v0.8.5+ with DHT pub/sub and RPC
- Working 3-node mesh test environment
- Basic UI components (from v0.1.x)

## Milestones

### Milestone 1: Protocol Infrastructure (Week 1)

**Goal:** Implement core protocol primitives

#### Tasks

- [ ] **1.1** Implement `register_player` RPC handler
  - Store player in local state
  - Send STORE to DHT
  - Publish `player_registered` event

- [ ] **1.2** Implement `unregister_player` RPC handler
  - Remove from local state
  - Remove from DHT
  - Publish `player_unregistered` event

- [ ] **1.3** Implement `find_opponents` RPC handler
  - Query DHT for waiting players
  - Filter out self
  - Return sorted by timestamp

- [ ] **1.4** Create event subscriptions in Coordinator
  - Subscribe to `arcade.snake.match_found`
  - Subscribe to `arcade.snake.game_started`
  - Subscribe to `arcade.snake.state_updated`
  - Subscribe to `arcade.snake.game_ended`

**Deliverable:** Players can register/unregister and see each other in DHT

---

### Milestone 2: Decentralized Matchmaking (Week 2)

**Goal:** Implement match discovery and confirmation

#### Tasks

- [ ] **2.1** Implement match proposal logic
  - Select opponent with lowest timestamp
  - Generate deterministic match_id
  - Publish `match_proposed` event

- [ ] **2.2** Implement match confirmation logic
  - Validate match_id
  - Check both players still available
  - Publish `match_found` event
  - Remove players from queue

- [ ] **2.3** Implement host selection algorithm
  - Compare node_ids lexicographically
  - Both coordinators reach same conclusion

- [ ] **2.4** Handle race conditions
  - First-match-wins semantics
  - Ignore duplicate proposals
  - TTL on pending matches

- [ ] **2.5** Add timeout handling
  - Match proposal timeout (5s)
  - Return unmatched players to queue

**Deliverable:** Players on different nodes automatically match

---

### Milestone 3: Game Server (Week 3)

**Goal:** Implement game logic and state management

#### Tasks

- [ ] **3.1** Create GameServer GenServer
  - Game state: snakes, food, scores
  - 200ms tick timer
  - Process player actions

- [ ] **3.2** Implement snake movement
  - Direction changes
  - Body segment following
  - Growth on food consumption

- [ ] **3.3** Implement collision detection
  - Wall collision
  - Self collision
  - Snake-to-snake collision
  - Head-to-head collision

- [ ] **3.4** Implement food mechanics
  - Random spawn (avoiding snakes)
  - Score increment
  - Snake growth

- [ ] **3.5** Implement win/loss conditions
  - Score limit (10 points)
  - Time limit (3 minutes)
  - Collision death
  - Forfeit on disconnect

- [ ] **3.6** Implement `submit_action` RPC handler
  - Validate action
  - Queue for next tick
  - Return acceptance status

**Deliverable:** Fully functional game server with all rules

---

### Milestone 4: Event Publishing (Week 4)

**Goal:** Broadcast game state over mesh

#### Tasks

- [ ] **4.1** Publish `game_started` with initial state
  - Starting positions (opposite corners)
  - Initial food position
  - Zero scores

- [ ] **4.2** Publish `state_updated` every tick
  - Current snake positions
  - Current food position
  - Current scores
  - Alive status

- [ ] **4.3** Publish `game_ended` on conclusion
  - Winner/loser IDs
  - Final scores
  - End reason
  - Game duration

- [ ] **4.4** Handle disconnect detection
  - Track last action timestamp per player
  - 10-second timeout
  - Publish forfeit event

**Deliverable:** Remote players receive real-time game state

---

### Milestone 5: UI Integration (Week 5)

**Goal:** Connect frontend to mesh events

#### Tasks

- [ ] **5.1** Update lobby UI
  - "Insert Coin" → calls `register_player`
  - Show queue position
  - Show "Searching for opponent..."

- [ ] **5.2** Add match found UI
  - Display opponent name
  - Show "Game starting..."
  - Transition to game screen

- [ ] **5.3** Create game canvas
  - 20x20 grid
  - Snake rendering (different colors)
  - Food rendering
  - Score display

- [ ] **5.4** Implement input handling
  - Arrow keys / WASD
  - Send to `submit_action` RPC
  - Prevent reverse direction

- [ ] **5.5** Add game end UI
  - Winner/loser announcement
  - Final scores
  - "Play Again" button

- [ ] **5.6** Handle state updates
  - Subscribe to `state_updated` events
  - Re-render on each tick
  - Smooth animations (optional)

**Deliverable:** Complete playable game in browser

---

### Milestone 6: Testing & Polish (Week 6)

**Goal:** Ensure stability and good UX

#### Tasks

- [ ] **6.1** Write unit tests for GameServer
  - Movement logic
  - Collision detection
  - Scoring
  - Win conditions

- [ ] **6.2** Write integration tests
  - Matchmaking flow
  - Complete game flow
  - Disconnect handling

- [ ] **6.3** Cross-peer testing
  - 3-node mesh test
  - Different browsers
  - Network latency simulation

- [ ] **6.4** Error handling improvements
  - Graceful degradation
  - User-friendly error messages
  - Retry logic

- [ ] **6.5** Performance optimization
  - Minimize event payload size
  - Efficient rendering
  - Memory cleanup

- [ ] **6.6** Documentation
  - Update README
  - Deployment guide
  - Protocol documentation review

**Deliverable:** Production-ready v0.2.0 release

---

## Timeline Summary

| Week | Milestone | Deliverable |
|------|-----------|-------------|
| 1 | Protocol Infrastructure | Register/unregister working |
| 2 | Decentralized Matchmaking | Cross-peer matching |
| 3 | Game Server | Game logic complete |
| 4 | Event Publishing | State broadcast working |
| 5 | UI Integration | Playable in browser |
| 6 | Testing & Polish | v0.2.0 release |

## Success Criteria

- [ ] Two players on different nodes can match
- [ ] Complete game plays without errors
- [ ] 10-second disconnect forfeit works
- [ ] Score/time limits trigger game end
- [ ] All collisions detected correctly
- [ ] No memory leaks over multiple games
- [ ] UI is responsive and intuitive

## Dependencies

- **Macula v0.8.5+**: DHT STORE/FIND_VALUE, pub/sub, RPC
- **NodeManager**: Working `call_service`, `publish`, `subscribe`
- **Docker Compose**: 3-node mesh test environment

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| DHT latency too high | Poor UX | Accept latency for v0.2, optimize in v0.3 |
| Race conditions in matching | Duplicate games | Deterministic algorithms, idempotency |
| Macula bugs block progress | Delays | Keep macula issues in separate backlog |
| UI complexity | Delays | Minimal viable UI first, polish later |

## Future Versions

### v0.3.0 (Planned)
- Spectator mode
- Replay system
- Leaderboard

### v0.4.0 (Planned)
- Power-ups
- Multiple game modes
- Sound effects

## References

- [Snake Duel Protocol](./SNAKE_DUEL_PROTOCOL.md)
- [Protocol Design Practices](/home/rl/work/github.com/macula-io/macula/architecture/PROTOCOL_DESIGN_PRACTICES.md)
- [Macula v0.8.5 Release Notes](/home/rl/work/github.com/macula-io/macula/CHANGELOG.md)
