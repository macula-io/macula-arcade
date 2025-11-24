#!/bin/bash
set -e

# Macula Arcade - Development Environment Deployment
# This deploys a separate dev instance on different ports

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_FILE="docker-compose.yml"
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

export BUILD_DATE
export VCS_REF

echo "=================================================="
echo "Macula Arcade - Development Environment"
echo "Version: dev"
echo "Git Commit: ${VCS_REF}"
echo "Build Date: ${BUILD_DATE}"
echo "=================================================="
echo ""

# Check if demo is running
demo_running=$(docker ps --filter "name=arcade-gateway" --format "{{.Names}}" 2>/dev/null || echo "")
if [ -n "$demo_running" ]; then
    echo "✓ Demo environment detected (running on ports 4000-4003)"
    echo "  Dev will use ports 5000-5003 (no conflict)"
    echo ""
fi

# Step 1: Stop existing dev containers
echo "Step 1/5: Stopping existing dev containers..."
docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true
echo "✓ Dev containers stopped"
echo ""

# Step 2: Build fresh images
echo "Step 2/5: Building dev images from local source..."
echo "  This builds from ./system/ directory"
echo "  (may take 2-3 minutes on first build)"
DOCKER_BUILDKIT=1 docker compose -f "$COMPOSE_FILE" build --no-cache
echo "✓ Images built"
echo ""

# Step 3: Start containers
echo "Step 3/5: Starting dev containers..."
docker compose -f "$COMPOSE_FILE" up -d
echo "✓ Containers started"
echo ""

# Step 4: Wait for health checks
echo "Step 4/5: Waiting for services to be healthy..."
max_attempts=60
attempt=0

check_health() {
    docker ps --filter "name=dev-" --format "{{.Names}}: {{.Status}}" | grep -v "healthy" > /dev/null
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
    echo "Check status: docker compose -f $COMPOSE_FILE ps"
else
    echo "✓ All services healthy!"
fi
echo ""

# Step 5: Display status
echo "Step 5/5: Deployment summary"
echo ""

echo "=================================================="
echo "Development Environment Ready!"
echo "=================================================="
echo ""
echo "Services running:"
docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "Access points (DEV):"
echo "  Gateway:   http://localhost:5000"
echo "  Peer 1:    http://localhost:5001"
echo "  Peer 2:    http://localhost:5002"
echo "  Bot Node:  http://localhost:5003"
echo ""
echo "Health checks (DEV):"
echo "  Gateway:   http://localhost:9080/health"
echo "  Peer 1:    http://localhost:9081/health"
echo "  Peer 2:    http://localhost:9082/health"
echo "  Bot Node:  http://localhost:9083/health"
echo ""

if [ -n "$demo_running" ]; then
    echo "Demo environment (STABLE) still running:"
    echo "  Gateway:   http://localhost:4000"
    echo "  Peer 1:    http://localhost:4001"
    echo "  Peer 2:    http://localhost:4002"
    echo "  Bot Node:  http://localhost:4003"
    echo ""
fi

echo "Commands:"
echo "  Logs:      docker compose -f $COMPOSE_FILE logs -f"
echo "  Stop:      docker compose -f $COMPOSE_FILE down"
echo "  Rebuild:   docker compose -f $COMPOSE_FILE up --build -d"
echo "  Restart:   docker compose -f $COMPOSE_FILE restart"
echo ""
echo "Development workflow:"
echo "  1. Make code changes in ./system/"
echo "  2. Rebuild: docker compose -f $COMPOSE_FILE up --build -d"
echo "  3. Test at http://localhost:5000"
echo ""
echo "Version: dev (${VCS_REF})"
echo "=================================================="
