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
