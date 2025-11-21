#!/bin/bash
set -e

# Quick deployment test script
# Run this to verify the demo deployment works correctly

COMPOSE_FILE="docker-compose.demo.yml"

echo "Testing Macula Arcade Demo Deployment"
echo "======================================"
echo ""

# Test 1: Check compose file exists
echo "Test 1: Checking files..."
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "✗ FAIL: $COMPOSE_FILE not found"
    exit 1
fi
echo "✓ Files exist"

# Test 2: Validate compose file
echo "Test 2: Validating docker-compose..."
if docker compose -f "$COMPOSE_FILE" config > /dev/null 2>&1; then
    echo "✓ Compose file valid"
else
    echo "✗ FAIL: Compose file has errors"
    docker compose -f "$COMPOSE_FILE" config
    exit 1
fi

# Test 3: Check for port conflicts
echo "Test 3: Checking for port conflicts..."
conflicts=0
for port in 4000 4001 4002 4003 8080 8081 8082 8083 4433 4434 4435 4436; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "  ⚠ Port $port is in use"
        conflicts=$((conflicts + 1))
    fi
done

if [ $conflicts -eq 0 ]; then
    echo "✓ No port conflicts"
elif [ $conflicts -le 12 ]; then
    echo "  Note: Ports in use (likely existing arcade containers)"
    echo "  Run: docker compose -f $COMPOSE_FILE down"
else
    echo "✗ Unexpected ports in use. Check manually: lsof -i :4000-4003"
fi

# Test 4: Check current container status
echo "Test 4: Checking current deployment..."
running=$(docker compose -f "$COMPOSE_FILE" ps --services --filter "status=running" 2>/dev/null | wc -l)
if [ "$running" -eq 4 ]; then
    echo "✓ All 4 services running"
    docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}"
elif [ "$running" -gt 0 ]; then
    echo "  ⚠ Only $running/4 services running"
    docker compose -f "$COMPOSE_FILE" ps
else
    echo "  No services running (expected if first deployment)"
fi

echo ""
echo "======================================"
echo "Pre-flight check complete!"
echo ""
echo "To deploy for demo:"
echo "  ./deploy-demo.sh"
echo ""
echo "Or manual deployment:"
echo "  docker compose -f $COMPOSE_FILE up -d"
echo "======================================"
