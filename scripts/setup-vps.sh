#!/bin/bash
set -e

# ============================================
# SmartBag — First-time VPS Setup
# ============================================
# Sets up Docker, GHCR login, and environment files.
# No service repos are cloned — images are pulled from GHCR.
#
# Usage: ./scripts/setup-vps.sh <domain> <email>
# Example: ./scripts/setup-vps.sh smartbag.in admin@smartbag.in

DOMAIN=${1:?"Usage: ./setup-vps.sh <domain> <email>"}
EMAIL=${2:?"Usage: ./setup-vps.sh <domain> <email>"}
DEPLOY_DIR="/opt/smartbag"
GITHUB_OWNER="nitin3150"

echo "==============================="
echo "  SmartBag — VPS Setup"
echo "  Domain: $DOMAIN"
echo "  Email:  $EMAIL"
echo "==============================="

# ─── Step 1: Install Docker ────────────────────────────
echo ""
echo "[1/6] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo "  Docker installed. You may need to log out and back in for group changes."
else
    echo "  Docker already installed."
fi

# ─── Step 2: Install Docker Compose plugin ─────────────
echo ""
echo "[2/6] Checking Docker Compose..."
if docker compose version &> /dev/null; then
    echo "  Docker Compose available."
else
    echo "  Installing Docker Compose plugin..."
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
fi

# ─── Step 3: Login to GHCR ────────────────────────────
echo ""
echo "[3/6] Logging into GitHub Container Registry..."
echo "  You need a GitHub Personal Access Token (PAT) with read:packages scope."
echo "  Create one at: https://github.com/settings/tokens/new"
echo ""
read -sp "  Enter your GHCR token: " GHCR_TOKEN
echo ""
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_OWNER" --password-stdin
echo "  Logged into GHCR."

# ─── Step 4: Set up deploy directory ──────────────────
echo ""
echo "[4/6] Setting up $DEPLOY_DIR..."
sudo mkdir -p $DEPLOY_DIR
sudo chown -R $USER:$USER $DEPLOY_DIR

if [ ! -d "$DEPLOY_DIR/.git" ]; then
    echo "  Cloning smartbag-deploy repo..."
    git clone "git@github.com:${GITHUB_OWNER}/smartbag-deploy.git" $DEPLOY_DIR
else
    echo "  Deploy repo already exists, pulling latest..."
    cd $DEPLOY_DIR && git pull
fi

cd $DEPLOY_DIR

# Verify required files exist
for f in docker-compose.yml docker-compose.prod.yml nginx/nginx.prod.conf nginx/nginx.base.conf; do
    if [ ! -f "$f" ]; then
        echo "  WARNING: $f not found!"
    fi
done

# ─── Step 5: Create .env files ────────────────────────
echo ""
echo "[5/6] Configuring environment..."

if [ ! -f ".env" ]; then
    cat > .env << ENVEOF
# SmartBag Production Environment
DOMAIN=$DOMAIN

# PostgreSQL
POSTGRES_USER=smartbag
POSTGRES_PASSWORD=$(openssl rand -hex 16)
POSTGRES_DB=smartbag_inventory

# MongoDB
MONGO_DB=smartbag
MONGO_ROOT_USER=smartbag_admin
MONGO_ROOT_PASSWORD=$(openssl rand -hex 16)

# Redis
REDIS_PASSWORD=$(openssl rand -hex 16)
ENVEOF
    echo "  Created .env with auto-generated passwords."
    echo "  IMPORTANT: Save these credentials securely!"
    echo ""
    cat .env
    echo ""
else
    echo "  .env already exists, skipping."
fi

# Prompt to create service env files
for svc in backend admin-backend; do
    if [ ! -f ".env.$svc" ]; then
        echo ""
        echo "  WARNING: .env.$svc not found."
        echo "  Create it from the template:"
        echo "    cp .env.$svc.example .env.$svc"
        echo "    nano .env.$svc"
    fi
done

# ─── Step 6: Configure nginx for domain ──────────────
echo ""
echo "[6/6] Configuring nginx for $DOMAIN..."
if [ -f "nginx/nginx.prod.conf" ]; then
    sed -i "s/yourdomain\.com/$DOMAIN/g" nginx/nginx.prod.conf
    echo "  Nginx configured for $DOMAIN"
fi

echo ""
echo "==============================="
echo "  VPS Setup Complete!"
echo "==============================="
echo ""
echo "  Next steps:"
echo "  1. Create service env files:"
echo "       cp .env.backend.example .env.backend"
echo "       cp .env.admin-backend.example .env.admin-backend"
echo "       # Edit both with production values"
echo ""
echo "  2. Configure DNS records (point all to your VPS IP):"
echo "       A    $DOMAIN           → $(curl -s ifconfig.me 2>/dev/null || echo '<VPS_IP>')"
echo "       A    www.$DOMAIN       → <same>"
echo "       A    api.$DOMAIN       → <same>"
echo "       A    admin.$DOMAIN     → <same>"
echo "       A    admin-api.$DOMAIN → <same>"
echo ""
echo "  3. Get SSL certificates:"
echo "       ./scripts/init-ssl.sh $DOMAIN $EMAIL"
echo ""
echo "  4. First deploy:"
echo "       ./scripts/deploy.sh"
echo ""
