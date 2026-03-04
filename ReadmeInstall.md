# Быстрый деплой на сервер (Docker + Nginx + S-UI + Let's Encrypt)

## 1) Подготовка DNS и портов

- Откройте входящие порты `80/tcp` и `443/tcp` на сервере.
- Убедитесь, что домены указывают на IP сервера:
  - `fish-house.su`
  - `www.fish-house.su`
  - `panel.fish-house.su`
- Если используете Cloudflare — на время выпуска сертификата поставьте **DNS only** (без проксирования).

## 2) Установка Docker (Ubuntu)

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo systemctl enable --now docker
```

## 3) Перейти в проект

```bash
cd /путь/к/Docker_S-UI-SAIT
```

## 4) Заполнить `.env`

Проверьте/задайте значения:

- `SUI_IMAGE` — реальный образ (не placeholder)
- `LETSENCRYPT_EMAIL` — ваша почта
- `ROOT_DOMAIN`, `WWW_DOMAIN`, `PANEL_DOMAIN` — ваши домены

Пример:

```dotenv
SUI_IMAGE=ghcr.io/alireza0/s-ui:latest
```

## 5) Права на скрипты и загрузка образов

```bash
chmod +x scripts/init-letsencrypt.sh scripts/renew-letsencrypt.sh
docker compose pull
```

## 6) Первый запуск + выпуск сертификата

```bash
./scripts/init-letsencrypt.sh
```

Скрипт:
- поднимет `s-ui` и `nginx` в bootstrap-режиме,
- выпустит сертификат,
- переключит Nginx на TLS-конфиг,
- перезагрузит Nginx.

## 7) Поднять стек

```bash
docker compose up -d
```

## 8) Проверка

```bash
docker compose ps
docker compose logs --tail=100 nginx s-ui
```

Панель: `https://panel.fish-house.su/app/`

После первого входа сразу смените дефолтный пароль S-UI (`admin/admin`).

---

## Автообновление сертификатов (рекомендуется)

```bash
mkdir -p logs
(crontab -l 2>/dev/null; echo '17 3 * * * cd /путь/к/Docker_S-UI-SAIT && ./scripts/renew-letsencrypt.sh >> /путь/к/Docker_S-UI-SAIT/logs/letsencrypt-renew.log 2>&1') | crontab -
```

Проверить cron-задачу:

```bash
crontab -l | grep renew-letsencrypt.sh
```
