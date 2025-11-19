# Macula Arcade

A decentralized multiplayer Snake Duel game built on the [Macula HTTP/3 mesh platform](https://github.com/macula-io/macula). Demonstrates cross-peer gameplay where game state is synchronized across a distributed mesh network.

## Features

- **Cross-peer multiplayer**: Players on different peers can compete in real-time
- **AI-controlled snakes**: Snakes battle autonomously (spectator mode)
- **Mesh pub/sub**: Game state synchronized via Macula's distributed pub/sub
- **Phoenix LiveView UI**: Real-time browser updates without polling

## Quick Start

### Docker CLI

```bash
docker run -d \
  --name macula-arcade \
  -p 4000:4000 \
  -e GATEWAY_HOST=gateway.example.com \
  -e GATEWAY_PORT=9000 \
  -e PEER_ID=arcade-peer1 \
  maculacid/macula-arcade:latest
```

Then open http://localhost:4000 in your browser.

### Docker Compose

```yaml
version: '3.8'

services:
  arcade:
    image: maculacid/macula-arcade:latest
    ports:
      - "4000:4000"
    environment:
      - GATEWAY_HOST=gateway.example.com
      - GATEWAY_PORT=9000
      - PEER_ID=arcade-peer1
      - PHX_HOST=localhost
      - SECRET_KEY_BASE=your-secret-key-base-here
```

### Multi-Peer Setup (Mesh Demo)

```yaml
version: '3.8'

services:
  gateway:
    image: maculacid/macula-arcade:latest
    ports:
      - "4000:4000"
    environment:
      - MACULA_MODE=gateway
      - PEER_ID=arcade-gateway

  peer1:
    image: maculacid/macula-arcade:latest
    ports:
      - "4001:4000"
    environment:
      - GATEWAY_HOST=gateway
      - GATEWAY_PORT=9000
      - PEER_ID=arcade-peer1

  peer2:
    image: maculacid/macula-arcade:latest
    ports:
      - "4002:4000"
    environment:
      - GATEWAY_HOST=gateway
      - GATEWAY_PORT=9000
      - PEER_ID=arcade-peer2
```

Open `http://localhost:4001` and `http://localhost:4002` in separate browsers, click "Find Game" on both, and watch the snakes battle across the mesh!

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GATEWAY_HOST` | Macula gateway hostname | `localhost` |
| `GATEWAY_PORT` | Macula gateway QUIC port | `9000` |
| `PEER_ID` | Unique identifier for this peer | `arcade-peer` |
| `PHX_HOST` | Phoenix host for URLs | `localhost` |
| `PORT` | HTTP port | `4000` |
| `SECRET_KEY_BASE` | Phoenix secret key | (generated) |

## Architecture

Macula Arcade uses the Macula mesh platform for:
- **Service Discovery**: DHT-based registration
- **Matchmaking**: Cross-peer player matching via pub/sub
- **Game Sync**: Real-time state updates over QUIC

## Links

- [Source Code](https://github.com/macula-io/macula-arcade)
- [Macula Platform](https://hexdocs.pm/macula)
- [Macula on Hex.pm](https://hex.pm/packages/macula)

## License

Apache-2.0
