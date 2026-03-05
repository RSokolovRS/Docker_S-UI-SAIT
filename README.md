# Nginx + S-UI + Let's Encrypt (Docker Compose) для fish-house.su

## Архитектура
- Docker Compose поднимает 3 сервиса: `nginx`, `s-ui`, `certbot` в общей сети `web`.
- Снаружи публикуются только порты `80` и `443` у `nginx`; у `s-ui` только `expose 2095/2096` (внутри сети Docker).
- Stage A (bootstrap): Nginx работает только по HTTP, обслуживает ACME challenge, заглушку и проксирует `panel` на S-UI.
- Сертификат выпускается через `certbot` в контейнере с `--webroot` (без `certbot --nginx` на хосте).
- После успешного выпуска `scripts/init-letsencrypt.sh` автоматически переключает Nginx на Stage B (TLS).
- Stage B: HTTP редиректится на HTTPS, кроме `/.well-known/acme-challenge/`; TLS только `TLSv1.2/TLSv1.3`.
- Домены: `fish-house.su` и `www.fish-house.su` -> заглушка; `panel.fish-house.su/app/` и `/sub/` -> reverse proxy в S-UI.
- Данные certbot хранятся строго в `./certbot/conf` и `./certbot/www`; данные S-UI — в Docker volume `s-ui-data`.
- Обновление сертификатов выполняется отдельным скриптом `renew-letsencrypt.sh` (cron/systemd), после обновления делается `nginx reload`.

## Дерево проекта
```text
fish-house/
├── .env
├── docker-compose.yml
├── certbot/
│   ├── conf/
│   └── www/
├── html/
│   └── index.html
├── nginx/
│   ├── nginx.conf
│   └── conf.d/
│       ├── fish-house.conf
│       └── panel.conf
└── scripts/
    ├── init-letsencrypt.sh
    └── renew-letsencrypt.sh
```

## Полные файлы

### docker-compose.yml
```yaml
services:
  nginx:
    image: nginx:1.27-alpine
    depends_on:
      - s-ui
    ports:
      - "80:80"
      - "443:443"
    environment:
      - TZ=${TZ}
    volumes:
      - ./nginx:/etc/nginx:ro
      - ./html:/usr/share/nginx/html:ro
      - ./certbot/www:/var/www/certbot:ro
      - ./certbot/conf:/etc/letsencrypt:ro
    networks:
      - web
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /var/cache/nginx
      - /var/run
      - /tmp
    security_opt:
      - no-new-privileges:true
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://127.0.0.1/healthz || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 15s

  s-ui:
    image: ${SUI_IMAGE}
    expose:
      - "2095"
      - "2096"
    environment:
      - TZ=${TZ}
    volumes:
      - s-ui-data:/etc/s-ui
    networks:
      - web
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true

  certbot:
    image: certbot/certbot:latest
    profiles:
      - manual
    volumes:
      - ./certbot/www:/var/www/certbot
      - ./certbot/conf:/etc/letsencrypt
    networks:
      - web
    restart: "no"

networks:
  web:
    driver: bridge

volumes:
  s-ui-data:
```

### .env
```dotenv
COMPOSE_PROJECT_NAME=fishhouse
TZ=Europe/Moscow

SUI_IMAGE=PLACEHOLDER_REPLACE_WITH_ACTUAL_SUI_IMAGE

ROOT_DOMAIN=fish-house.su
WWW_DOMAIN=www.fish-house.su
PANEL_DOMAIN=panel.fish-house.su

LETSENCRYPT_EMAIL=admin@fish-house.su
LETSENCRYPT_STAGING=0
```

### nginx/nginx.conf
```nginx
user nginx;
worker_processes auto;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /dev/stdout main;
    error_log /dev/stderr warn;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 4096;

    server_tokens off;
    autoindex off;

    client_max_body_size 20m;
    proxy_connect_timeout 30s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    send_timeout 60s;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header Referrer-Policy no-referrer-when-downgrade always;

    include /etc/nginx/conf.d/*.conf;
}
```

### nginx/conf.d/fish-house.conf
```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name fish-house.su www.fish-house.su;

    root /usr/share/nginx/html;
    index index.html;

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
        try_files $uri /index.html;
    }
}
```

### nginx/conf.d/panel.conf
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name panel.fish-house.su;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type "text/plain";
        try_files $uri =404;
    }

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
```

### html/index.html
```html
<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>fish-house.su</title>
  <style>
    :root { color-scheme: dark; }
    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
      background: #0b1220;
      color: #e5e7eb;
    }
    .card {
      text-align: center;
      padding: 32px;
      border: 1px solid #334155;
      border-radius: 12px;
      background: #0f172a;
      max-width: 560px;
      width: calc(100% - 48px);
    }
    h1 { margin: 0 0 8px; font-size: 28px; }
    p { margin: 0; opacity: .9; }
  </style>
</head>
<body>
  <main class="card">
    <h1>fish-house.su</h1>
    <p>Сайт в подготовке. Скоро здесь появится контент.</p>
  </main>
</body>
</html>
```

### scripts/init-letsencrypt.sh
```bash
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
    ((elapsed++))
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
docker compose up -d s-ui
ensure_service_running s-ui 60

docker compose up -d nginx
ensure_service_running nginx 60

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
ensure_service_running nginx 30
docker compose exec -T nginx nginx -t
docker compose exec -T nginx nginx -s reload

log "Готово: HTTPS включен."
log "ВАЖНО: войдите в S-UI (admin/admin) и немедленно смените пароль."
```

### scripts/renew-letsencrypt.sh
```bash
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

log "Запускаю certbot renew..."
set +e
docker compose --profile manual run --rm certbot renew --webroot -w /var/www/certbot
RENEW_EXIT=$?
set -e

if [[ $RENEW_EXIT -ne 0 ]]; then
  die "certbot renew завершился с кодом $RENEW_EXIT"
fi

log "Проверяю конфигурацию и перезагружаю nginx..."
docker compose exec -T nginx nginx -t
docker compose exec -T nginx nginx -s reload

log "Renewal завершен успешно."
exit 0
```

## Пошаговый запуск (с нуля, Ubuntu 22.04/24.04)
- 1) Установка Docker + Compose plugin:
```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release ufw dnsutils
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
docker compose version
```

- 2) Firewall (UFW) по требованию:
```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 2095/tcp
sudo ufw deny 2096/tcp
sudo ufw --force enable
sudo ufw status verbose
```

- 3) Создать структуру проекта:
```bash
mkdir -p ~/deploy/fish-house/{nginx/conf.d,html,scripts,certbot/conf,certbot/www,logs}
cd ~/deploy/fish-house
```

- 4) Вставить файлы из секции выше, затем:
```bash
chmod +x scripts/init-letsencrypt.sh scripts/renew-letsencrypt.sh
```

- 5) Cloudflare DNS (обязательно DNS only / серое облако):
  - `A` запись `fish-house.su` -> IP сервера
  - `A` запись `www` -> IP сервера (или CNAME на `fish-house.su`)
  - `A` запись `panel` -> IP сервера
  - У всех записей Proxy Status = `DNS only`

- 6) `SUI_IMAGE` — PLACEHOLDER, подставить актуальный образ:
```bash
docker search s-ui | head -n 20
docker pull ghcr.io/alireza0/s-ui:latest
sed -i 's|^SUI_IMAGE=.*|SUI_IMAGE=ghcr.io/alireza0/s-ui:latest|' .env
```

- 7) Запуск и первичный выпуск сертификата:
```bash
docker compose pull
./scripts/init-letsencrypt.sh
docker compose up -d
```

Если на этом шаге увидели `cannot exec in a stopped container`, переходите в секцию `Troubleshooting` ниже.

- 8) Включить автообновление сертификатов (cron):
```bash
(crontab -l 2>/dev/null; echo '17 3 * * * cd ~/deploy/fish-house && ./scripts/renew-letsencrypt.sh >> ~/deploy/fish-house/logs/letsencrypt-renew.log 2>&1') | crontab -
crontab -l | grep renew-letsencrypt.sh
```

## Проверки
- Состояние контейнеров:
```bash
docker compose ps
```
Ожидаемо: `nginx` и `s-ui` в `Up`, `certbot` не висит постоянно.

- HTTP -> HTTPS:
```bash
curl -I http://fish-house.su
```
Ожидаемо: `301` и `Location: https://fish-house.su/...` (после `init-letsencrypt.sh`).

- HTTPS сайта:
```bash
curl -I https://fish-house.su
```
Ожидаемо: `200 OK`.

- HTTPS панели:
```bash
curl -I https://panel.fish-house.su/app/
```
Ожидаемо: `200` или `302` (в зависимости от ответа S-UI).

- Сертификат:
```bash
openssl s_client -connect fish-house.su:443 -servername fish-house.su </dev/null 2>/dev/null | openssl x509 -noout -issuer -subject -dates -ext subjectAltName
```
Ожидаемо: валидные `notBefore/notAfter`, SAN содержит `fish-house.su`, `www.fish-house.su`, `panel.fish-house.su`.

- Логи:
```bash
docker compose logs --tail=100 nginx s-ui
```

- Проверка renewal в dry-run:
```bash
docker compose --profile manual run --rm certbot renew --dry-run --webroot -w /var/www/certbot
```
Ожидаемо: симуляция успешна.

## Hardening / Security
- Немедленно сменить дефолтные `admin/admin` в S-UI после первого входа.
- Ограничить доступ к панели по IP в `nginx/conf.d/panel.conf` (в `server` для `443`):
  - `allow <ваш_IP>;`
  - `deny all;`
- На хосте включить `fail2ban` (опционально) для SSH и веб-логов.
- Регулярно обновлять образы: `docker compose pull && docker compose up -d`.
- Делать бэкап `s-ui-data` и каталога `certbot/conf`.
- Отключить SSH-вход по паролю после первичной настройки (перейти на ключи).
- Листинг директорий уже отключен (`autoindex off`), версия Nginx скрыта (`server_tokens off`).

## Troubleshooting
- `OCI runtime exec failed: exec failed: cannot exec in a stopped container` во время `./scripts/init-letsencrypt.sh`:
  - Это означает, что контейнер `nginx` остановился до выполнения `docker compose exec ... nginx -t`.
  - Диагностика:
    - `docker compose ps`
    - `docker compose logs --tail=150 nginx`
    - `docker compose logs --tail=150 s-ui`
  - Частые причины:
    - ошибка в `nginx/nginx.conf` или `nginx/conf.d/*.conf`;
    - в `.env` некорректный `SUI_IMAGE` или не заполнены переменные доменов/email;
    - локально изменённые конфиги отличаются от рабочих примеров.
  - Что делать:
    - исправить конфиг/`.env`;
    - проверить конфиг командой `docker compose run --rm nginx nginx -t`;
    - запустить `docker compose up -d s-ui nginx` и повторить `./scripts/init-letsencrypt.sh`.

- `404` на `panel.../app/`:
  - Проверьте, что в S-UI реально используются пути `/app/` и `/sub/`.
  - Проверьте конфиг и перезагрузку: `docker compose exec -T nginx nginx -t && docker compose exec -T nginx nginx -s reload`.

- `502 Bad Gateway`:
  - Обычно `s-ui` не стартовал или неверный `SUI_IMAGE`.
  - Команды: `docker compose logs s-ui`, `docker compose ps`, `docker compose exec -T nginx getent hosts s-ui`.

- Ошибки SSL:
  - Убедитесь, что в Cloudflare серое облако (`DNS only`), а не proxy.
  - Убедитесь, что извне открыты `80/443`.
  - Проверьте наличие файлов в `certbot/conf/live/fish-house.su/`.

- `challenge failed`:
  - Проверьте, что `location /.well-known/acme-challenge/ { root /var/www/certbot; }` есть для нужного host.
  - Проверьте volume-мэппинг `./certbot/www:/var/www/certbot`.
  - Проверьте DNS-резолв: `dig +short fish-house.su`, `dig +short panel.fish-house.su`.

## Rollback
- Быстрый откат к bootstrap HTTP (если `init` уже делал backup):
```bash
cd ~/deploy/fish-house
cp nginx/conf.d/fish-house.conf.bootstrap.bak nginx/conf.d/fish-house.conf
cp nginx/conf.d/panel.conf.bootstrap.bak nginx/conf.d/panel.conf
docker compose exec -T nginx nginx -t
docker compose exec -T nginx nginx -s reload
```

- Полный откат стека:
```bash
cd ~/deploy/fish-house
docker compose down
docker compose up -d s-ui nginx
```

- Полный откат + удаление certbot-состояния:
```bash
cd ~/deploy/fish-house
docker compose down
rm -rf certbot/conf/live certbot/conf/archive certbot/conf/renewal
docker compose up -d s-ui nginx
```
