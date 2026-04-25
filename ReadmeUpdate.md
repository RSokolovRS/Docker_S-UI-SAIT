# Обновление проекта (Docker + Nginx + S-UI)

Этот файл описывает безопасное обновление проекта при выходе новых версий.

## 1) Перейти в папку проекта

```bash
cd /opt/docker-s-ui-sait
```

Если проект расположен в другом месте, используйте ваш путь.

## 2) Проверить локальные изменения

```bash
git status
```

Если есть незакоммиченные изменения, сохраните их (commit/stash), чтобы `git pull` прошел без конфликтов.

## 3) Обновить код репозитория

```bash
git pull --ff-only origin main
```

## 4) Подтянуть свежие Docker-образы

```bash
docker compose pull
```

## 5) Перезапустить сервисы с новыми версиями

```bash
docker compose up -d --remove-orphans
```

## 6) Проверить состояние и логи

```bash
docker compose ps
docker compose logs --tail=100 nginx s-ui
```

## Важные замечания

- `scripts/init-letsencrypt.sh` запускается только для первичной инициализации/выпуска сертификата. Не используйте его при каждом обновлении.
- Для регулярного продления сертификатов используйте `scripts/renew-letsencrypt.sh` (через `cron`).
- Данные S-UI сохраняются в Docker volume `s-ui-data` и не должны теряться при обычном обновлении.
- Если в `.env` указан образ с тегом `latest`, команда `docker compose pull` подтянет новую версию автоматически.

## Рекомендуемый бэкап перед обновлением

Минимум перед обновлением сохраните:

- `.env`
- `certbot/conf`

Пример:

```bash
cp .env .env.backup.$(date +%F)
tar -czf certbot-conf-backup-$(date +%F).tar.gz certbot/conf
```
