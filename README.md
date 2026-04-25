# sokolrock.org — Docker (Nginx + S-UI + Let’s Encrypt)

Статичный сайт в `./html/`. Панель S-UI: **`https://panel.sokolrock.org`**.  
Основной сайт: **`https://sokolrock.org`** и `https://www.sokolrock.org`.

По SNI с порта 443 (как в исходном [Docker_S-UI-SAIT](https://github.com/RSokolovRS/Docker_S-UI-SAIT)):

- `sokolrock.org`, `www.sokolrock.org`, `panel.sokolrock.org` → внутренний HTTPS Nginx на `127.0.0.1:4443`
- `hy2.sokolrock.org` → Hysteria2 (порт s-ui 28888)
- `vless.sokolrock.org` → VLESS (порт s-ui 28889)

## Подготовка

1. **DNS** (у регистратора / Cloudflare): A-записи на IP сервера:
   - `sokolrock.org`, `www`, `panel`, `hy2`, `vless` — на один и тот же IP.
2. **Cloudflare**: для записей, участвующих в Let’s Encrypt, временно **DNS only** (серый облачок), не Proxied, пока не получите сертификат.
3. **Порты**: `80` и `443` (TCP) + `443/UDP` для HY2, свободны снаружи.
4. Скопируйте `.env.example` → `.env` и укажите:
   - `SUI_IMAGE` — реальный образ S-UI
   - `LETSENCRYPT_EMAIL`
   - при необходимости домены (по умолчанию уже `sokolrock.org` и `panel.sokolrock.org`).

## Первый запуск (TLS + nginx)

**Не** запускайте `docker compose up` до инициализации, если в `certbot/conf` ещё нет сертификатов: в `nginx/conf.d` по умолчанию включён `listen 4443 ssl`, без ключей Nginx не стартует.

Выполните (сервер, из корня репозитория):

```bash
chmod +x scripts/init-letsencrypt.sh scripts/renew-letsencrypt.sh
./scripts/init-letsencrypt.sh
```

Скрипт:

1. При отсутствии `certbot/conf/live/<CERT_LIVE_NAME>/` переключает vhost'ы в режим **только порт 80** (ACME)
2. Поднимает `s-ui` и `nginx`
3. Выпускает **один** SAN-сертификат на все перечисленные в `.env` домены
4. Пишет production-конфиги с `4443` + TLS и перезагружает Nginx

`CERT_LIVE_NAME` (по умолчанию `sokolrock.org`) — имя каталога `live/` в certbot, должно совпадать с **первым** доменом в цепочке (используется в путях `ssl_certificate`).

## Повседневное

```bash
docker compose up -d
```

Обновление сертификатов (cron, раз в 12 часов/день — на усмотрение):

```bash
./scripts/renew-letsencrypt.sh
```

## Репозиторий

Подключение к GitHub (ваш клон):

```bash
git remote add origin git@github.com:RSokolovRS/Docker_S-UI-SAIT.git
# или сменить URL, если origin уже есть:
# git remote set-url origin git@github.com:RSokolovRS/Docker_S-UI-SAIT.git
```

Редактируйте **только** файлы в `html/`, либо копируйте их в `html/` перед деплоем.
