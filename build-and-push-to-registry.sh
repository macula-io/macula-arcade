#!/usr/bin/env bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

# Configuration
IMAGE_NAME="macula/arcade"
REGISTRY="registry.macula.local"
TAG="${1:-latest}"

print_status "Building macula-arcade image..."
docker build \
    --build-arg CACHE_BUST=$(date +%s) \
    -t ${REGISTRY}/${IMAGE_NAME}:${TAG} \
    -f Dockerfile \
    .

print_status "Pushing to registry ${REGISTRY}..."
docker push ${REGISTRY}/${IMAGE_NAME}:${TAG}

print_status "Image pushed successfully!"
echo ""
echo "Image available at:"
echo "  ${REGISTRY}/${IMAGE_NAME}:${TAG}"
echo "  localhost:5001/${IMAGE_NAME}:${TAG} (from within KinD)"
