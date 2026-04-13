#!/bin/bash
set -e

# ============================================
# SmartBag — Deploy Service(s)
# ============================================
# Pulls latest images from GHCR and restarts services.
# Called by GitHub Actions after image push, or manually.
#
# Usage:
#   ./scripts/deploy.sh                    # deploy all app services
#   ./scripts/deploy.sh backend            # deploy only backend
#   ./scripts/deploy.sh admin-backend      # deploy only admin-backend
#   ./scripts/deploy.sh admin-panel        # deploy only admin-panel

cd "$(dirname "$0")/.."

COMPOSE="docker compose -f docker-compose.yml -f docker-compose.prod.yml"
SERVICES=${@:-"backend admin-backend admin-panel"}
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Prevent concurrent deploys with flock
LOCKFILE="/tmp/smartbag-deploy.lock"
exec 200>"$LOCKFILE"
if ! flock -n 200; then
    echo "Another deploy is in progress. Waiting..."
    flock 200
fi

echo "==============================="
echo "  SmartBag — Deploy"
echo "  Services: $SERVICES"
echo "  Time:     $TIMESTAMP"
echo "==============================="

# Step 1: Pull latest images
echo ""
echo "[1/4] Pulling latest images..."
for service in $SERVICES; do
    echo "  Pulling $service..."
    $COMPOSE pull "$service"
done

# Step 2: Restart services with new images
echo ""
echo "[2/4] Restarting services..."
$COMPOSE up -d --no-build --force-recreate $SERVICES

# Step 3: Run migrations if admin-backend was updated
if echo "$SERVICES" | grep -q "admin-backend"; then
    echo ""
    echo "[3/4] Waiting for admin-backend to start..."
    sleep 10
    echo "  Running Alembic migrations..."
    $COMPOSE exec -T admin-backend alembic upgrade head 2>/dev/null \
        || echo "  (skipped — no migrations or already up to date)"
else
    echo ""
    echo "[3/4] Skipping migrations (admin-backend not in update list)"
fi

# Step 4: Cleanup old images
echo ""
echo "[4/4] Cleaning up old images..."
docker image prune -f

echo ""
echo "==============================="
echo "  Deploy complete!"
echo "==============================="
$COMPOSE ps
