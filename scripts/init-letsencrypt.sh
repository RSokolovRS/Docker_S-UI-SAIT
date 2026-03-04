#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

log() { echo "[$(date '+%F %T')] $*"; }
die() { echo "[$(date '+%F %T')] ERROR: $*" >&2; exit 1; }

if ! command -v docker >/dev/null 2>&1; then
  die "Docker не установлен."
fi

if ! docker compose version >/dev/null 2>&1; then
  die "Плагин docker compose не найден."
fi

if [[ ! -f ".env" ]]; then
  die ".env не найден в $PROJECT_ROOT"
fi

set -a
source ./.env
set +a

: "${SUI_IMAGE:?Укажите SUI_IMAGE в .env}"
: "${LETSENCRYPT_EMAIL:?Укажите LETSENCRYPT_EMAIL в .env}"
: "${ROOT_DOMAIN:?Укажите ROOT_DOMAIN в .env}"
: "${WWW_DOMAIN:?Укажите WWW_DOMAIN в .env}"
: "${PANEL_DOMAIN:?Укажите PANEL_DOMAIN в .env}"

if [[ "$SUI_IMAGE" == PLACEHOLDER* ]]; then
  die "SUI_IMAGE содержит PLACEHOLDER. Подставьте актуальный образ S-UI."
fi

FISH_CONF="nginx/conf.d/fish-house.conf"
PANEL_CONF="nginx/conf.d/panel.conf"

[[ -f "$FISH_CONF" ]] || die "Не найден $FISH_CONF"
[[ -f "$PANEL_CONF" ]] || die "Не найден $PANEL_CONF"

mkdir -p certbot/www certbot/conf

log "Запускаю s-ui и nginx в bootstrap (HTTP) режиме..."
docker compose up -d s-ui nginx

log "Проверяю синтаксис nginx..."
docker compose exec -T nginx nginx -t

CERTBOT_STAGING_ARG=()
if [[ "${LETSENCRYPT_STAGING:-0}" == "1" ]]; then
  CERTBOT_STAGING_ARG+=(--staging)
  log "Включен Let's Encrypt staging режим."
fi

log "Запрашиваю сертификат Let's Encrypt..."
if ! docker compose --profile manual run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  --email "$LETSENCRYPT_EMAIL" \
  --agree-tos \
  --no-eff-email \
  --rsa-key-size 4096 \
  "${CERTBOT_STAGING_ARG[@]}" \
  -d "$ROOT_DOMAIN" \
  -d "$WWW_DOMAIN" \
  -d "$PANEL_DOMAIN"; then
  die "Выпуск сертификата не удался. Проверьте DNS (Cloudflare DNS only), порты 80/443 и логи certbot."
fi

[[ -f "${FISH_CONF}.bootstrap.bak" ]] || cp "$FISH_CONF" "${FISH_CONF}.bootstrap.bak"
[[ -f "${PANEL_CONF}.bootstrap.bak" ]] || cp "$PANEL_CONF" "${PANEL_CONF}.bootstrap.bak"

log "Переключаю nginx на production TLS конфиг..."
cat > "$FISH_CONF" <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name fish-house.su www.fish-house.su;

    location = /healthz {
        access_log off;
        add_header Content-Type text/plain;
        return 200 "ok\n";
    }

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type "text/plain";
        try_files $uri =404;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name fish-house.su www.fish-house.su;

    ssl_certificate /etc/letsencrypt/live/fish-house.su/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/fish-house.su/privkey.pem;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri /index.html;
    }
}
EOF

cat > "$PANEL_CONF" <<'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name panel.fish-house.su;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type "text/plain";
        try_files $uri =404;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name panel.fish-house.su;

    ssl_certificate /etc/letsencrypt/live/fish-house.su/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/fish-house.su/privkey.pem;

    location = / {
        return 302 /app/;
    }

    location /app/ {
        proxy_http_version 1.1;
        proxy_pass http://s-ui:2095/app/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /sub/ {
        proxy_http_version 1.1;
        proxy_pass http://s-ui:2096/sub/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        return 404;
    }
}
EOF

log "Проверяю и перезагружаю nginx..."
docker compose exec -T nginx nginx -t
docker compose exec -T nginx nginx -s reload

log "Готово: HTTPS включен."
log "ВАЖНО: войдите в S-UI (admin/admin) и немедленно смените пароль."
