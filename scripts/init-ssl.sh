#!/bin/bash
set -e

# ============================================
# SmartBag — SSL Certificate Setup
# ============================================
# Gets Let's Encrypt certificates for all subdomains
#
# Usage: ./scripts/init-ssl.sh <domain> <email>
# Example: ./scripts/init-ssl.sh smartbag.in admin@smartbag.in

DOMAIN=${1:?"Usage: ./init-ssl.sh <domain> <email>"}
EMAIL=${2:?"Usage: ./init-ssl.sh <domain> <email>"}

cd "$(dirname "$0")/.."

echo "==============================="
echo "  SmartBag — SSL Setup"
echo "  Domain: $DOMAIN"
echo "  Email:  $EMAIL"
echo "==============================="

# Step 1: Create temporary nginx config for certbot challenge
echo ""
echo "[1/4] Starting nginx in HTTP-only mode..."

mkdir -p nginx/tmp
cat > nginx/tmp/certbot-init.conf << 'INITEOF'
events { worker_connections 1024; }
http {
    server {
        listen 80;
        server_name _;
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        location / {
            return 200 'SmartBag SSL init in progress';
            add_header Content-Type text/plain;
        }
    }
}
INITEOF

# Start only nginx and certbot services with temp config
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d nginx
docker cp nginx/tmp/certbot-init.conf smartbag-nginx:/etc/nginx/nginx.conf
docker exec smartbag-nginx nginx -s reload

# Step 2: Request certificate for all subdomains
echo ""
echo "[2/4] Requesting SSL certificate..."
echo "  Domains: $DOMAIN, www.$DOMAIN, api.$DOMAIN, admin.$DOMAIN, admin-api.$DOMAIN"

docker compose -f docker-compose.yml -f docker-compose.prod.yml run --rm certbot \
    certbot certonly --webroot -w /var/www/certbot \
    -d "$DOMAIN" \
    -d "www.$DOMAIN" \
    -d "api.$DOMAIN" \
    -d "admin.$DOMAIN" \
    -d "admin-api.$DOMAIN" \
    --email "$EMAIL" --agree-tos --no-eff-email

# Step 3: Clean up temp config
echo ""
echo "[3/4] Cleaning up..."
rm -rf nginx/tmp

# Step 4: Restart with full config
echo ""
echo "[4/4] Restarting nginx with SSL configuration..."
docker compose -f docker-compose.yml -f docker-compose.prod.yml restart nginx

echo ""
echo "==============================="
echo "  SSL Certificate Obtained!"
echo "==============================="
echo ""
echo "  Certificates cover:"
echo "    - $DOMAIN"
echo "    - www.$DOMAIN"
echo "    - api.$DOMAIN"
echo "    - admin.$DOMAIN"
echo "    - admin-api.$DOMAIN"
echo ""
echo "  Auto-renewal is handled by the certbot container."
echo ""
echo "  Next: Run ./scripts/deploy.sh"
echo ""
