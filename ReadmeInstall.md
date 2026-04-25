# Быстрый деплой на сервер (Docker + Nginx + S-UI + Let's Encrypt)

## 1) Подготовка DNS и портов

- Откройте входящие порты `80/tcp` и `443/tcp` на сервере, а также SSH-порт хоста (например, `27272/tcp`).
- Убедитесь, что домены указывают на IP сервера:
  - `fish-house.su`
  - `www.fish-house.su`
  - `panel.fish-house.su`
  - `hy2.fish-house.su`
  - `vless.fish-house.su`
- Если используете Cloudflare — на время выпуска сертификата поставьте **DNS only** (без проксирования).

## 2) Установка Docker (Ubuntu)

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo systemctl enable --now docker
```

## 3) Скачать проект и перейти в папку

Рекомендуемый путь на сервере: `/opt/docker-s-ui-sait`.

```bash
sudo mkdir -p /opt/docker-s-ui-sait
sudo chown -R $USER:$USER /opt/docker-s-ui-sait
cd /opt
git clone https://github.com/RSokolovRS/Docker_S-UI-SAIT.git docker-s-ui-sait
cd /opt/docker-s-ui-sait
```

Если проект уже скопирован на сервер, просто перейдите в его папку:

```bash
cd /opt/docker-s-ui-sait
```

## 4) Создать `.env` из шаблона и заполнить

Если в проекте есть `.env.example`, создайте рабочий файл `.env`:

```bash
cp .env.example .env
```

Если `.env` уже существует, не перезаписывайте его — просто отредактируйте текущий файл.

Что нужно проверить/задать в `.env`:

- `SUI_IMAGE` — имя Docker-образа для сервиса S-UI в формате `registry/repository:tag`.
  - Это не placeholder и не произвольный текст.
  - Для этого проекта используйте:
    - `SUI_IMAGE=ghcr.io/alireza0/s-ui:latest`
  - Откуда брать: из документации/README проекта и списка образов, которые реально доступны в реестре контейнеров.
- `LETSENCRYPT_EMAIL` — ваша почта для уведомлений Let's Encrypt.
- `ROOT_DOMAIN`, `WWW_DOMAIN`, `PANEL_DOMAIN`, `HY2_DOMAIN`, `VLESS_DOMAIN` — ваши домены.

Проверка, что образ доступен:

```bash
docker pull ghcr.io/alireza0/s-ui:latest
```

Пример блока `.env`:

```dotenv
SUI_IMAGE=ghcr.io/alireza0/s-ui:latest
LETSENCRYPT_EMAIL=admin@fish-house.su
ROOT_DOMAIN=fish-house.su
WWW_DOMAIN=www.fish-house.su
PANEL_DOMAIN=panel.fish-house.su
HY2_DOMAIN=hy2.fish-house.su
VLESS_DOMAIN=vless.fish-house.su
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

Важно для текущей схемы:
- Внешний `443` обрабатывается через `stream` + SNI маршрутизацию.
- HTTP(S) сайт и панель обслуживаются внутренними HTTPS-серверами Nginx на `4443`.
- Панель и подписки проксируются как обычный HTTP backend: `s-ui:2095` и `s-ui:2096`.
- Для stream backend в `s-ui` используются внутренние порты `28888` (Hysteria2) и `28889` (VLESS-TCP).

Если на этом шаге появилась ошибка:

```text
OCI runtime exec failed: exec failed: cannot exec in a stopped container
```

это означает, что контейнер `nginx` остановился до проверки `nginx -t`.

Быстрая диагностика:

```bash
docker compose ps
docker compose logs --tail=150 nginx
docker compose logs --tail=150 s-ui
```

Частые причины:

- в логах `nginx` ошибка `open() "/etc/nginx/mime.types" failed`:
  - причина: смонтирована вся папка `./nginx:/etc/nginx:ro`, из-за чего в контейнере пропадает `mime.types`;
  - решение: в `docker-compose.yml` оставить раздельные mounts:
    - `./nginx/nginx.conf:/etc/nginx/nginx.conf:ro`
    - `./nginx/conf.d:/etc/nginx/conf.d:ro`
- ошибка в `nginx/nginx.conf` или `nginx/conf.d/*.conf`;
- в `.env` некорректный `SUI_IMAGE` или не заполнены домены/email;
- случайно изменённые конфиги отличаются от шаблона проекта.

Как исправить:

```bash
docker compose run --rm nginx nginx -t
docker compose up -d --force-recreate nginx
./scripts/init-letsencrypt.sh
```

Если `docker compose run --rm nginx nginx -t` показывает ошибку синтаксиса, исправьте конфиг и повторите команды выше.

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

Настройки протоколов в панели S-UI:
- HY2: [HY2.md](HY2.md)
- VLESS-TCP: [VLESS.md](VLESS.md)

После первого входа сразу смените дефолтный пароль S-UI (`admin/admin`).

---

## Автообновление сертификатов (рекомендуется)

```bash
mkdir -p logs
(crontab -l 2>/dev/null; echo '17 3 * * * cd /opt/docker-s-ui-sait && ./scripts/renew-letsencrypt.sh >> /opt/docker-s-ui-sait/logs/letsencrypt-renew.log 2>&1') | crontab -
```

Проверить cron-задачу:

```bash
crontab -l | grep renew-letsencrypt.sh
```
