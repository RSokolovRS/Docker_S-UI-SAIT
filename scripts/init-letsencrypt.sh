#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

log() { echo "[$(date '+%F %T')] $*"; }
die() { echo "[$(date '+%F %T')] ERROR: $*" >&2; exit 1; }

service_running() {
  local service="$1"
  docker compose ps --status running --services "$service" 2>/dev/null | grep -qx "$service"
}

wait_service_running() {
  local service="$1"
  local timeout="${2:-30}"
  local elapsed=0
  while (( elapsed < timeout )); do
    if service_running "$service"; then
      return 0
    fi
    sleep 1
    ((elapsed++)) || true
  done
  return 1
}

print_service_logs() {
  local service="$1"
  log "Последние логи сервиса $service:"
  docker compose logs --tail=120 "$service" || true
}

ensure_service_running() {
  local service="$1"
  local timeout="${2:-30}"
  if ! wait_service_running "$service" "$timeout"; then
    print_service_logs "$service"
    die "Сервис $service не перешёл в состояние running за ${timeout}с."
  fi
}

write_bootstrap_http_only() {
  cat > "$SITE_CONF" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${ROOT_DOMAIN} ${WWW_DOMAIN};

    location = /healthz {
        access_log off;
        add_header Content-Type text/plain;
        return 200 "ok\n";
    }

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type "text/plain";
        try_files \$uri =404;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF
  cat > "$PANEL_CONF" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${PANEL_DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type "text/plain";
        try_files \$uri =404;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF
  log "Записан bootstrap (только порт 80) для ACME, затем certbot -> live/${CERT_LIVE_NAME}/"
}

write_production_vhosts() {
  cat > "$SITE_CONF" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${ROOT_DOMAIN} ${WWW_DOMAIN};

    location = /healthz {
        access_log off;
        add_header Content-Type text/plain;
        return 200 "ok\n";
    }

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type "text/plain";
        try_files \$uri =404;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 4443 ssl;
    listen [::]:4443 ssl;
    http2 on;
    server_name ${ROOT_DOMAIN} ${WWW_DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${CERT_LIVE_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${CERT_LIVE_NAME}/privkey.pem;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF
  cat > "$PANEL_CONF" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${PANEL_DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type "text/plain";
        try_files \$uri =404;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 4443 ssl;
    listen [::]:4443 ssl;
    http2 on;
    server_name ${PANEL_DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${CERT_LIVE_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${CERT_LIVE_NAME}/privkey.pem;

    location = / {
        return 302 /app/;
    }

    location /app/ {
        proxy_http_version 1.1;
        proxy_pass http://s-ui:2095;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /sub/ {
        proxy_http_version 1.1;
        proxy_pass http://s-ui:2096;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        return 404;
    }
}
EOF
}

if ! command -v docker >/dev/null 2>&1; then
  die "Docker не установлен."
fi
if ! docker compose version >/dev/null 2>&1; then
  die "Плагин docker compose не найден."
fi
if [[ ! -f ".env" ]]; then
  die ".env не найден в $PROJECT_ROOT (скопируйте .env.example -> .env)."
fi

set -a
# shellcheck disable=SC1091
source ./.env
set +a

: "${SUI_IMAGE:?Укажите SUI_IMAGE в .env}"
: "${LETSENCRYPT_EMAIL:?Укажите LETSENCRYPT_EMAIL в .env}"
: "${ROOT_DOMAIN:?Укажите ROOT_DOMAIN в .env}"
: "${WWW_DOMAIN:?Укажите WWW_DOMAIN в .env}"
: "${PANEL_DOMAIN:?Укажите PANEL_DOMAIN в .env}"

HY2_DOMAIN="${HY2_DOMAIN:-hy2.${ROOT_DOMAIN}}"
VLESS_DOMAIN="${VLESS_DOMAIN:-vless.${ROOT_DOMAIN}}"
CERT_LIVE_NAME="${CERT_LIVE_NAME:-$ROOT_DOMAIN}"

if [[ "$SUI_IMAGE" == PLACEHOLDER* ]]; then
  die "SUI_IMAGE содержит PLACEHOLDER. Подставьте актуальный образ S-UI."
fi

SITE_CONF="nginx/conf.d/sokolrock.conf"
PANEL_CONF="nginx/conf.d/panel.conf"
[[ -d "nginx/conf.d" ]] || die "Нет каталога nginx/conf.d"

mkdir -p certbot/www certbot/conf

NEED_CERT=0
if [[ ! -f "certbot/conf/live/${CERT_LIVE_NAME}/fullchain.pem" ]]; then
  NEED_CERT=1
  log "Сертификат live/${CERT_LIVE_NAME} не найден. Режим первичной настройки (HTTP-80, затем certbot)."
  write_bootstrap_http_only
  [[ -f "${SITE_CONF}.bootstrap.bak" ]] || cp "$SITE_CONF" "${SITE_CONF}.bootstrap.bak" 2>/dev/null || true
  [[ -f "${PANEL_CONF}.bootstrap.bak" ]] || cp "$PANEL_CONF" "${PANEL_CONF}.bootstrap.bak" 2>/dev/null || true
else
  log "Сертификат найден, nginx может стартовать с TLS на 4443."
fi

log "Запускаю s-ui..."
docker compose up -d s-ui
ensure_service_running s-ui 60

log "Запускаю nginx..."
docker compose up -d nginx
ensure_service_running nginx 60

log "Проверяю синтаксис nginx..."
docker compose exec -T nginx nginx -t

CERTBOT_STAGING_ARG=()
if [[ "${LETSENCRYPT_STAGING:-0}" == "1" ]]; then
  CERTBOT_STAGING_ARG+=(--staging)
  log "Включен Let's Encrypt staging."
fi

if [[ "$NEED_CERT" -eq 1 ]]; then
  log "Выпускаю сертификат Let's Encrypt (webroot)..."
  if ! docker compose --profile manual run --rm certbot certonly \
    --webroot -w /var/www/certbot \
    --email "$LETSENCRYPT_EMAIL" \
    --agree-tos \
    --no-eff-email \
    --rsa-key-size 4096 \
    "${CERTBOT_STAGING_ARG[@]}" \
    -d "$ROOT_DOMAIN" \
    -d "$WWW_DOMAIN" \
    -d "$PANEL_DOMAIN" \
    -d "$HY2_DOMAIN" \
    -d "$VLESS_DOMAIN"; then
    die "certbot certonly не удался. Проверьте DNS (A-записи на этот сервер, для Cloudflare - DNS only), порт 80 снаружи, логи certbot."
  fi
  log "Включаю production vhost'ы (4443 + TLS)..."
  write_production_vhosts
  docker compose exec -T nginx nginx -t
  docker compose exec -T nginx nginx -s reload
  log "Готово. Сайт: https://${ROOT_DOMAIN}/  Панель: https://${PANEL_DOMAIN}/"
  exit 0
fi

log "Обновляю/расширяю сертификат (если добавлены новые -d)..."
if ! docker compose --profile manual run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  --email "$LETSENCRYPT_EMAIL" \
  --agree-tos \
  --no-eff-email \
  --rsa-key-size 4096 \
  --expand \
  "${CERTBOT_STAGING_ARG[@]}" \
  -d "$ROOT_DOMAIN" \
  -d "$WWW_DOMAIN" \
  -d "$PANEL_DOMAIN" \
  -d "$HY2_DOMAIN" \
  -d "$VLESS_DOMAIN"; then
  die "certbot certonly (expand) не удался."
fi

write_production_vhosts
docker compose exec -T nginx nginx -t
docker compose exec -T nginx nginx -s reload
log "Готово. nginx с актуальными сертификатами."
exit 0
