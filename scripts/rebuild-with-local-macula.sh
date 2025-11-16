#!/bin/bash
set -e

echo "=========================================="
echo "Rebuilding Macula Arcade with Macula v0.7.1"
echo "=========================================="

# Copy Macula source into build context temporarily
echo "Copying Macula source into build context..."
rm -rf system/macula_local
cp -r ../macula system/macula_local

# Update mix.exs to use local copy
echo "Updating mix.exs to use local Macula..."
cd system/apps/macula_arcade
sed -i 's|{:macula, path: "../../../../../../macula", override: true}|{:macula, path: "../../macula_local", override: true}|' mix.exs
cd ../../..

# Prune Docker cache
echo "Pruning Docker build cache..."
docker builder prune -af

# Build images
echo "Building Docker images..."
docker-compose -f docker-compose.mesh-test.yml build --no-cache

# Restore original path
echo "Restoring original mix.exs..."
cd system/apps/macula_arcade
sed -i 's|{:macula, path: "../../macula_local", override: true}|{:macula, path: "../../../../../../macula", override: true}|' mix.exs
cd ../../..

# Clean up temporary copy
echo "Cleaning up temporary Macula copy..."
rm -rf system/macula_local

echo ""
echo "=========================================="
echo "Build complete! Starting mesh network..."
echo "=========================================="

# Start the mesh network
docker-compose -f docker-compose.mesh-test.yml up -d

# Wait for services to be healthy
echo ""
echo "Waiting for services to start..."
sleep 5

# Check status
docker-compose -f docker-compose.mesh-test.yml ps

echo ""
echo "=========================================="
echo "Mesh network is running!"
echo "=========================================="
echo "Gateway: http://localhost:4000"
echo "Peer 1:  http://localhost:4001"
echo "Peer 2:  http://localhost:4002"
echo "Peer 3:  http://localhost:4003"
echo ""
echo "Open multiple browsers and click 'Find Game' to test matchmaking!"
echo "=========================================="
