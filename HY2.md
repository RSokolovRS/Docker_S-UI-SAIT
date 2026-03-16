# HY2 (Hysteria2) для этого проекта

## Что уже настроено в инфраструктуре
- Внешний порт: 443 UDP на nginx.
- Внутренний backend: s-ui:28888.
- Домен для клиента: hy2.fish-house.su.
- Сертификаты лежат в certbot и уже используются nginx.

Важно: для UDP 443 в текущей схеме весь трафик уходит на HY2 backend.

## Настройка inbound в S-UI
1. Protocol: Hysteria2.
2. Listen/Port: 28888.
3. Transport: UDP.
4. Domain (SNI/ServerName): hy2.fish-house.su.
5. Users: добавьте пароль (или пользователей) по вашей политике доступа.
6. Obfs: включайте только если действительно нужен и задайте одинаковый пароль на клиенте.

## TLS в окне "Добавить TLS"
1. Режим: Использовать текст.
2. Сертификат: вставить содержимое fullchain.pem.
3. Ключ: вставить содержимое privkey.pem.
4. Отключить SNI: выключено.
5. Разрешить небезопасное: выключено.
6. ACME: выключено (сертификат уже выпускается проектом).
7. ECH: выключено.

Откуда брать файлы для вставки:
- fullchain.pem: certbot/conf/live/fish-house.su/fullchain.pem
- privkey.pem: certbot/conf/live/fish-house.su/privkey.pem

Важно после перевыпуска сертификата:
- Если выполнялся scripts/init-letsencrypt.sh или certbot renew/certonly, заново вставьте актуальные fullchain.pem и privkey.pem в TLS inbound HY2.
- Причина: в режиме "Использовать текст" S-UI хранит PEM в конфиге inbound и не подхватывает изменения файлов автоматически.

Рекомендуемые параметры TLS:
- Min version: 1.2.
- Max version: 1.3.
- ALPN: h3 (если поле доступно).

## Настройка клиента
- Address: hy2.fish-house.su.
- Port: 443.
- Transport: UDP/QUIC (Hysteria2).
- TLS: включен.
- SNI: hy2.fish-house.su.
- Insecure/Skip cert verify: выключено.
- Password/Obfs: строго как в inbound.

## Проверка после сохранения
1. Убедиться, что inbound в S-UI активен и слушает 28888.
2. Проверить с клиента подключение на hy2.fish-house.su:443.
3. Если нет подключения:
- проверить DNS запись hy2.fish-house.su;
- проверить, что сертификат содержит hy2.fish-house.su в SAN;
- если сертификат недавно перевыпускали, заново вставить fullchain.pem/privkey.pem в TLS inbound;
- проверить, что на хосте слушается 443 UDP;
- проверить логи nginx и s-ui.

## Частые ошибки
- Неверный домен в сертификате: TLS handshake error.
- Включен Insecure на клиенте и несоответствие политике: нестабильные подключения.
- Не совпадает Obfs/Password между клиентом и inbound.
