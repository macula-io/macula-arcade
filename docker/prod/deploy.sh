#!/usr/bin/env bash
set -euo pipefail

# Macula Arcade Production Environment
#
# Production deployment using Dockerfile.prod with runtime cert generation
# Optimized for cloud/k8s deployments
#
# Usage:
#   ./deploy.sh build     - Build production containers
#   ./deploy.sh up        - Start containers
#   ./deploy.sh down      - Stop containers
#   ./deploy.sh deploy    - Clean + build + start
#   ./deploy.sh logs      - Follow all logs
#   ./deploy.sh clean     - Remove everything

# Generate cache bust
export CACHE_BUST=$(date +%s)

COMPOSE_FILE="docker-compose.yml"

case "${1:-help}" in
  build)
    echo "=== Building Production Environment (v0.10.0) ==="
    echo "Cache bust: ${CACHE_BUST}"
    docker compose -f ${COMPOSE_FILE} build --no-cache
    ;;

  up)
    echo "=== Starting Production Environment ==="
    docker compose -f ${COMPOSE_FILE} up -d
    echo ""
    echo "✅ Containers started!"
    echo ""
    echo "Gateway:  http://localhost:4000"
    echo "Peer 1:   http://localhost:4001"
    echo "Peer 2:   http://localhost:4002"
    echo "Bot 1:    http://localhost:4003"
    echo ""
    echo "💡 Tip: ./deploy.sh logs"
    ;;

  down)
    echo "=== Stopping Production Environment ==="
    docker compose -f ${COMPOSE_FILE} down
    ;;

  deploy)
    echo "=== Deploying Production Environment ==="
    docker compose -f ${COMPOSE_FILE} down -v
    docker compose -f ${COMPOSE_FILE} build --no-cache
    docker compose -f ${COMPOSE_FILE} up -d
    echo ""
    echo "✅ Deployed!"
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
🚀 Macula Arcade Production Environment

Purpose:
  Production deployment with optimized images
  Uses Dockerfile.prod (Debian Slim, health checks, runtime certs)
  Suitable for cloud/k8s deployments

Commands:
  build           Build production containers (with cache bust)
  up              Start containers
  down            Stop containers
  deploy          Clean + build + start (recommended)
  logs            Follow all logs
  logs-gateway    Follow gateway logs
  logs-peer1      Follow peer1 logs
  logs-peer2      Follow peer2 logs
  logs-bot        Follow bot logs
  clean           Remove everything (ask confirmation)

Examples:
  ./deploy.sh deploy        # Fresh deployment
  ./deploy.sh logs-gateway  # Watch gateway logs
  ./deploy.sh down          # Stop everything

URLs:
  Gateway:  http://localhost:4000
  Peer 1:   http://localhost:4001
  Peer 2:   http://localhost:4002
  Bot 1:    http://localhost:4003

Note: Ports conflict with demo environment.
      Only run one at a time!

For Kubernetes deployments, see:
  k8s/README.md
EOF
    ;;
esac
