#!/bin/bash

# Test Macula Arcade mesh deployment
# This script builds and deploys a multi-node mesh network for testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "=========================================="
echo "Macula Arcade Mesh Network Test"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

print_status "Docker is running"

# Clean up any existing containers
print_status "Cleaning up existing containers..."
docker-compose -f docker-compose.mesh-test.yml down -v 2>/dev/null || true

# Prune Docker build cache for fresh build
print_warning "Pruning Docker build cache for clean build..."
docker builder prune -af

# Build the image
print_status "Building Macula Arcade Docker image..."
docker-compose -f docker-compose.mesh-test.yml build --no-cache

# Start the mesh network
print_status "Starting mesh network (1 gateway + 3 peers)..."
docker-compose -f docker-compose.mesh-test.yml up -d

# Wait for services to be healthy
print_status "Waiting for services to start..."
echo ""

for service in arcade-gateway arcade-peer1 arcade-peer2 arcade-peer3; do
    echo -n "  Waiting for $service... "
    timeout=60
    elapsed=0

    while [ $elapsed -lt $timeout ]; do
        if docker inspect "$service" --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
            print_status "healthy"
            break
        fi

        if [ $elapsed -eq $timeout ]; then
            print_error "timeout"
            echo ""
            print_error "Service $service failed to become healthy"
            docker logs "$service" 2>&1 | tail -50
            exit 1
        fi

        sleep 2
        elapsed=$((elapsed + 2))
    done
done

echo ""
print_status "All services are healthy!"
echo ""

# Display access information
echo "=========================================="
echo "Mesh Network Ready!"
echo "=========================================="
echo ""
echo "Gateway Node:"
echo "  URL:  http://localhost:4000"
echo "  Mesh: https://arcade-gateway:4433"
echo ""
echo "Peer Nodes:"
echo "  Peer 1: http://localhost:4001"
echo "  Peer 2: http://localhost:4002"
echo "  Peer 3: http://localhost:4003"
echo ""
echo "=========================================="
echo "Testing Instructions:"
echo "=========================================="
echo ""
echo "1. Open multiple browser windows:"
echo "   - Gateway: http://localhost:4000"
echo "   - Peer 1:  http://localhost:4001"
echo "   - Peer 2:  http://localhost:4002"
echo "   - Peer 3:  http://localhost:4003"
echo ""
echo "2. Click 'INSERT COIN' on Snake Battle Royale"
echo "   on different nodes to test mesh gameplay"
echo ""
echo "3. Watch logs with:"
echo "   docker-compose -f docker-compose.mesh-test.yml logs -f"
echo ""
echo "4. Stop the mesh:"
echo "   docker-compose -f docker-compose.mesh-test.yml down"
echo ""
echo "=========================================="
echo "Mesh Status:"
echo "=========================================="
echo ""

# Check mesh connectivity
print_status "Checking mesh connectivity..."
echo ""

for port in 4000 4001 4002 4003; do
    node_name=""
    case $port in
        4000) node_name="Gateway" ;;
        4001) node_name="Peer 1 " ;;
        4002) node_name="Peer 2 " ;;
        4003) node_name="Peer 3 " ;;
    esac

    if curl -s -f "http://localhost:$port/" > /dev/null 2>&1; then
        print_status "$node_name (port $port) is responding"
    else
        print_error "$node_name (port $port) is not responding"
    fi
done

echo ""
print_status "Mesh network test deployment complete!"
echo ""
