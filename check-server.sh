#!/bin/bash

# Check if the server is running
# Usage: ./check-server.sh

CONTAINER_NAME="tstc-slack-bot-container"
PORT="${PORT:-3000}"

echo "🔍 Checking server status..."
echo ""

# Check if Docker container is running
echo "1️⃣ Checking Docker container status..."
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "   ✅ Container '${CONTAINER_NAME}' is running"
    docker ps --filter "name=${CONTAINER_NAME}" --format "   Container ID: {{.ID}}\n   Status: {{.Status}}\n   Ports: {{.Ports}}"
else
    echo "   ❌ Container '${CONTAINER_NAME}' is NOT running"
    echo ""
    echo "   To start the server, run:"
    echo "   ./docker-run-local.sh"
    exit 1
fi

echo ""
echo "2️⃣ Checking server health endpoint..."
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT}/health 2>/dev/null || echo "000")

if [ "$HEALTH_RESPONSE" = "200" ]; then
    echo "   ✅ Health check passed (HTTP 200)"
    curl -s http://localhost:${PORT}/health
    echo ""
else
    echo "   ❌ Health check failed (HTTP $HEALTH_RESPONSE)"
    echo "   Server may still be starting up. Wait a few seconds and try again."
fi

echo ""
echo "3️⃣ Checking ping endpoint..."
PING_RESPONSE=$(curl -s http://localhost:${PORT}/api/ping 2>/dev/null || echo "ERROR")
if [ "$PING_RESPONSE" != "ERROR" ] && echo "$PING_RESPONSE" | grep -q '"ok":true'; then
    echo "   ✅ Ping endpoint responded:"
    echo "$PING_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$PING_RESPONSE"
else
    echo "   ⚠️  Ping endpoint not responding"
fi

echo ""
echo "4️⃣ Container logs (last 10 lines):"
docker logs --tail 10 ${CONTAINER_NAME} 2>/dev/null || echo "   Could not fetch logs"

echo ""
echo "📋 Quick commands:"
echo "   View logs:        docker logs -f ${CONTAINER_NAME}"
echo "   Stop server:      docker stop ${CONTAINER_NAME}"
echo "   Restart server:   docker restart ${CONTAINER_NAME}"
echo "   Health check:     curl http://localhost:${PORT}/health"
echo "   Ping endpoint:    curl http://localhost:${PORT}/api/ping"

