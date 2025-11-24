#!/usr/bin/env bash
set -euo pipefail

# Macula Arcade Test Environment
#
# Tests latest code from local macula + macula-arcade repos
# Builds from scratch with cache busting
#
# Usage:
#   ./test.sh build     - Build containers
#   ./test.sh up        - Start containers
#   ./test.sh down      - Stop containers
#   ./test.sh rebuild   - Clean + build + start
#   ./test.sh logs      - Follow all logs
#   ./test.sh clean     - Remove everything

# Generate cache bust
export CACHE_BUST=$(date +%s)

COMPOSE_FILE="docker-compose.yml"

case "${1:-help}" in
  build)
    echo "=== Building Test Environment (v0.10.0) ==="
    echo "Cache bust: ${CACHE_BUST}"
    docker compose -f ${COMPOSE_FILE} build --no-cache
    ;;

  up)
    echo "=== Starting Test Environment ==="
    docker compose -f ${COMPOSE_FILE} up -d
    echo ""
    echo "✅ Containers started!"
    echo ""
    echo "Gateway:  http://localhost:4000"
    echo "Peer 1:   http://localhost:4001"
    echo "Peer 2:   http://localhost:4002"
    echo "Bot 1:    http://localhost:4003"
    echo ""
    echo "💡 Tip: ./test.sh logs"
    ;;

  down)
    echo "=== Stopping Test Environment ==="
    docker compose -f ${COMPOSE_FILE} down
    ;;

  rebuild)
    echo "=== Rebuilding Test Environment ==="
    docker compose -f ${COMPOSE_FILE} down -v
    docker compose -f ${COMPOSE_FILE} build --no-cache
    docker compose -f ${COMPOSE_FILE} up -d
    echo ""
    echo "✅ Rebuilt and started!"
    echo ""
    echo "Gateway:  http://localhost:4000"
    echo "Peer 1:   http://localhost:4001"
    echo "Peer 2:   http://localhost:4002"
    echo "Bot 1:    http://localhost:4003"
    ;;

  logs)
    docker compose -f ${COMPOSE_FILE} logs -f
    ;;

  logs-gateway)
    docker compose -f ${COMPOSE_FILE} logs -f arcade-gateway
    ;;

  logs-peer1)
    docker compose -f ${COMPOSE_FILE} logs -f arcade-peer1
    ;;

  logs-peer2)
    docker compose -f ${COMPOSE_FILE} logs -f arcade-peer2
    ;;

  logs-bot)
    docker compose -f ${COMPOSE_FILE} logs -f arcade-bot1
    ;;

  clean)
    echo "⚠️  WARNING: This removes all containers, volumes, and images!"
    read -p "Continue? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
      docker compose -f ${COMPOSE_FILE} down -v --rmi all
      echo "✅ Cleaned"
    else
      echo "Cancelled"
    fi
    ;;

  help|*)
    cat <<EOF
🧪 Macula Arcade Test Environment

Purpose:
  Test latest code from local repos (macula + macula-arcade)
  Platform Layer integration (Raft + CRDTs)
  Macula v0.10.0 features

Commands:
  build           Build containers (with cache bust)
  up              Start containers
  down            Stop containers
  rebuild         Clean + build + start (recommended)
  logs            Follow all logs
  logs-gateway    Follow gateway logs
  logs-peer1      Follow peer1 logs
  logs-peer2      Follow peer2 logs
  logs-bot        Follow bot logs
  clean           Remove everything (ask confirmation)

Examples:
  ./test.sh rebuild         # Fresh build and start
  ./test.sh logs-gateway    # Watch gateway logs
  ./test.sh down            # Stop everything

URLs:
  Gateway:  http://localhost:4000
  Peer 1:   http://localhost:4001
  Peer 2:   http://localhost:4002
  Bot 1:    http://localhost:4003

Note: Ports conflict with demo environment.
      Only run one at a time!
EOF
    ;;
esac
