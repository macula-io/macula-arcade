#!/bin/bash
set -e

# Macula Arcade v0.2.2 - Stable Demo Deployment Script
# This script pulls pre-built images from Docker Hub for reliable demos

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERSION="0.2.2"
IMAGE="maculacid/macula-arcade:${VERSION}"
COMPOSE_FILE="docker-compose.yml"

echo "=================================================="
echo "Macula Arcade Demo Deployment"
echo "Version: ${VERSION}"
echo "Image: ${IMAGE}"
echo "=================================================="
echo ""

# Step 1: Stop existing containers
echo "Step 1/5: Stopping existing containers..."
docker compose -f docker-compose.mesh-test.yml down 2>/dev/null || true
docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true
echo "✓ Containers stopped"
echo ""

# Step 2: Pull latest images from Docker Hub
echo "Step 2/5: Pulling images from Docker Hub..."
echo "  Pulling ${IMAGE}..."
docker pull "${IMAGE}"
echo "✓ Images pulled"
echo ""

# Step 3: Start containers
echo "Step 3/5: Starting containers..."
docker compose -f "$COMPOSE_FILE" up -d
echo "✓ Containers started"
echo ""

# Step 4: Wait for health checks
echo "Step 4/5: Waiting for services to be healthy..."
echo "  This may take 30-60 seconds..."

max_attempts=60
attempt=0

check_health() {
    docker ps --filter "name=arcade-demo-" --format "{{.Names}}: {{.Status}}" | grep -v "healthy" > /dev/null
    return $?
}

while check_health && [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt + 1))
    printf "."
    sleep 2
done
echo ""

if [ $attempt -eq $max_attempts ]; then
    echo "⚠ Warning: Services did not become healthy within timeout"
    echo "Check status with: docker compose -f $COMPOSE_FILE ps"
else
    echo "✓ All services healthy!"
fi
echo ""

# Step 5: Display deployment status
echo "Step 5/5: Deployment complete!"
echo ""

echo "=================================================="
echo "Demo Environment Ready!"
echo "=================================================="
echo ""
echo "Services running:"
docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "Access points:"
echo "  Gateway:   http://localhost:4000"
echo "  Peer 1:    http://localhost:4001"
echo "  Peer 2:    http://localhost:4002"
echo "  Bot Node:  http://localhost:4003"
echo ""
echo "Health checks:"
echo "  Gateway:   http://localhost:8080/health"
echo "  Peer 1:    http://localhost:8081/health"
echo "  Peer 2:    http://localhost:8082/health"
echo "  Bot Node:  http://localhost:8083/health"
echo ""
echo "Commands:"
echo "  Logs:      docker compose -f $COMPOSE_FILE logs -f"
echo "  Stop:      docker compose -f $COMPOSE_FILE down"
echo "  Restart:   docker compose -f $COMPOSE_FILE restart"
echo ""
echo "Image: ${IMAGE}"
echo "Git commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
echo "=================================================="
