#!/bin/bash
# Rebuild and test the arcade containers

set -e

echo "=== Stopping existing containers ==="
docker compose down 2>/dev/null || true

echo "=== Building images with cache bust ==="
CACHE_BUST=$(date +%s)
docker compose build --build-arg CACHE_BUST="$CACHE_BUST"

echo "=== Starting containers ==="
docker compose up -d

echo "=== Waiting for services to start ==="
sleep 10

echo "=== Checking container health ==="
docker compose ps

echo "=== Container TLS fingerprints (should be unique) ==="
for c in arcade-peer1 arcade-peer2 arcade-peer3; do
    echo "$c:"
    docker exec "$c" openssl x509 -in /opt/macula/certs/cert.pem -fingerprint -sha256 -noout 2>/dev/null | head -1 || echo "  (not available)"
done

echo ""
echo "=== Services ready! ==="
echo "  Peer 1: http://localhost:5001/snake"
echo "  Peer 2: http://localhost:5002/snake"
echo "  Peer 3: http://localhost:5003/snake"
