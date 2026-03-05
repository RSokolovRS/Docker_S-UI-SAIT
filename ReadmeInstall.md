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
- `ROOT_DOMAIN`, `WWW_DOMAIN`, `PANEL_DOMAIN` — ваши домены.

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
(crontab -l 2>/dev/null; echo '17 3 * * * cd /opt/docker-s-ui-sait && ./scripts/renew-letsencrypt.sh >> /opt/docker-s-ui-sait/logs/letsencrypt-renew.log 2>&1') | crontab -
```

Проверить cron-задачу:

```bash
crontab -l | grep renew-letsencrypt.sh
```
