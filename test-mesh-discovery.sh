#!/bin/bash
#
# Macula Arcade - Multi-Instance Mesh Discovery Test
#
# This script:
# 1. Builds the Docker image
# 2. Starts two arcade instances
# 3. Monitors logs for mesh connectivity
# 4. Provides URLs for testing
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="macula-arcade"
IMAGE_TAG="latest"
CONTAINER1_NAME="arcade1"
CONTAINER2_NAME="arcade2"
PORT1=4000
PORT2=4001

echo -e "${BLUE}=== Macula Arcade - Multi-Instance Test ===${NC}\n"

# Step 1: Clean up any existing containers
echo -e "${YELLOW}Step 1: Cleaning up existing containers...${NC}"
docker rm -f ${CONTAINER1_NAME} ${CONTAINER2_NAME} 2>/dev/null || true
echo -e "${GREEN}✓ Cleanup complete${NC}\n"

# Step 2: Build Docker image
echo -e "${YELLOW}Step 2: Building Docker image...${NC}"
cd /home/rl/work/github.com/macula-io/macula-arcade/system

echo "Building ${IMAGE_NAME}:${IMAGE_TAG}..."
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} . --progress=plain 2>&1 | tail -20

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Docker image built successfully${NC}\n"
else
    echo -e "${RED}✗ Docker build failed${NC}"
    exit 1
fi

# Step 3: Start first instance
echo -e "${YELLOW}Step 3: Starting first arcade instance (${CONTAINER1_NAME})...${NC}"
docker run -d \
    -p ${PORT1}:4000 \
    --name ${CONTAINER1_NAME} \
    ${IMAGE_NAME}:${IMAGE_TAG}

echo -e "${GREEN}✓ ${CONTAINER1_NAME} started on port ${PORT1}${NC}"
sleep 2

# Step 4: Start second instance
echo -e "${YELLOW}Step 4: Starting second arcade instance (${CONTAINER2_NAME})...${NC}"
docker run -d \
    -p ${PORT2}:4000 \
    --name ${CONTAINER2_NAME} \
    ${IMAGE_NAME}:${IMAGE_TAG}

echo -e "${GREEN}✓ ${CONTAINER2_NAME} started on port ${PORT2}${NC}\n"
sleep 3

# Step 5: Check container status
echo -e "${YELLOW}Step 5: Checking container status...${NC}"
CONTAINER1_STATUS=$(docker inspect -f '{{.State.Status}}' ${CONTAINER1_NAME})
CONTAINER2_STATUS=$(docker inspect -f '{{.State.Status}}' ${CONTAINER2_NAME})

echo "  ${CONTAINER1_NAME}: ${CONTAINER1_STATUS}"
echo "  ${CONTAINER2_NAME}: ${CONTAINER2_STATUS}"

if [ "$CONTAINER1_STATUS" != "running" ] || [ "$CONTAINER2_STATUS" != "running" ]; then
    echo -e "${RED}✗ One or more containers failed to start${NC}"
    echo -e "\nContainer 1 logs:"
    docker logs ${CONTAINER1_NAME} 2>&1 | tail -20
    echo -e "\nContainer 2 logs:"
    docker logs ${CONTAINER2_NAME} 2>&1 | tail -20
    exit 1
fi

echo -e "${GREEN}✓ Both containers running${NC}\n"

# Step 6: Monitor mesh connectivity
echo -e "${YELLOW}Step 6: Checking Macula mesh connectivity...${NC}"
echo "Waiting for services to initialize..."
sleep 5

echo -e "\n${BLUE}Container 1 (${CONTAINER1_NAME}) logs:${NC}"
docker logs ${CONTAINER1_NAME} 2>&1 | grep -i "macula\|mesh\|node" | tail -10 || echo "No mesh logs yet"

echo -e "\n${BLUE}Container 2 (${CONTAINER2_NAME}) logs:${NC}"
docker logs ${CONTAINER2_NAME} 2>&1 | grep -i "macula\|mesh\|node" | tail -10 || echo "No mesh logs yet"

# Step 7: Test URLs
echo -e "\n${GREEN}=== Test Ready! ===${NC}\n"
echo -e "${BLUE}Open these URLs in separate browser windows:${NC}"
echo -e "  Player 1: ${GREEN}http://localhost:${PORT1}/snake${NC}"
echo -e "  Player 2: ${GREEN}http://localhost:${PORT2}/snake${NC}"
echo ""
echo -e "${YELLOW}Instructions:${NC}"
echo "  1. Open both URLs in different browser windows"
echo "  2. Click 'Find Game' on both"
echo "  3. Watch the automatic matchmaking via Macula mesh!"
echo "  4. Use arrow keys to play"
echo ""
echo -e "${BLUE}Monitoring commands:${NC}"
echo -e "  View container 1 logs: ${YELLOW}docker logs -f ${CONTAINER1_NAME}${NC}"
echo -e "  View container 2 logs: ${YELLOW}docker logs -f ${CONTAINER2_NAME}${NC}"
echo -e "  Stop both containers:  ${YELLOW}docker rm -f ${CONTAINER1_NAME} ${CONTAINER2_NAME}${NC}"
echo ""

# Step 8: Follow logs (optional)
echo -e "${YELLOW}Following logs from both containers (Ctrl+C to stop)...${NC}\n"
sleep 2

# Follow logs from both containers with labels
docker logs -f ${CONTAINER1_NAME} 2>&1 | sed "s/^/[${CONTAINER1_NAME}] /" &
PID1=$!

docker logs -f ${CONTAINER2_NAME} 2>&1 | sed "s/^/[${CONTAINER2_NAME}] /" &
PID2=$!

# Cleanup function
cleanup() {
    echo -e "\n\n${YELLOW}Stopping log monitoring...${NC}"
    kill $PID1 $PID2 2>/dev/null || true
    echo -e "${GREEN}Done!${NC}"
    echo ""
    echo -e "${BLUE}Containers are still running. To stop them:${NC}"
    echo -e "  ${YELLOW}docker rm -f ${CONTAINER1_NAME} ${CONTAINER2_NAME}${NC}"
    echo ""
}

trap cleanup EXIT INT TERM

# Wait for user to interrupt
wait
