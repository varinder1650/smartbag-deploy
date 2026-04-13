#!/bin/bash
set -e

# ============================================
# SmartBag — Rollback to specific image tag
# ============================================
# Usage: ./scripts/rollback.sh <service> <image-tag>
# Example: ./scripts/rollback.sh backend sha-abc123f

SERVICE=${1:?"Usage: ./scripts/rollback.sh <service> <image-tag>"}
TAG=${2:?"Usage: ./scripts/rollback.sh <service> <image-tag>"}
OWNER="nitin3150"

cd "$(dirname "$0")/.."

COMPOSE="docker compose -f docker-compose.yml -f docker-compose.prod.yml"
IMAGE="ghcr.io/${OWNER}/smartbag-${SERVICE}:${TAG}"

echo "==============================="
echo "  SmartBag — Rollback"
echo "  Service: $SERVICE"
echo "  Image:   $IMAGE"
echo "==============================="

# Pull the specific tagged image
echo ""
echo "[1/2] Pulling $IMAGE..."
docker pull "$IMAGE"

# Tag it as :latest so compose picks it up
echo ""
echo "[2/2] Restarting $SERVICE with rolled-back image..."
docker tag "$IMAGE" "ghcr.io/${OWNER}/smartbag-${SERVICE}:latest"
$COMPOSE up -d --no-build --force-recreate "$SERVICE"

echo ""
echo "==============================="
echo "  Rollback complete!"
echo "==============================="
$COMPOSE ps
