# VLESS-TCP для этого проекта

## Что уже настроено в инфраструктуре
- Внешний порт: 443 TCP на nginx.
- Маршрутизация по SNI в nginx stream:
  - vless.fish-house.su -> s-ui:28889.
  - panel/site домены идут на внутренний HTTPS nginx.
- Внутренний backend VLESS: s-ui:28889.

## Настройка inbound в S-UI
1. Protocol: VLESS.
2. Port: 28889.
3. Network: TCP.
4. Clients: добавьте UUID пользователей.
5. Flow: по вашей клиентской схеме (обычно none, если отдельно не требуется XTLS-специфика).

## TLS в окне "Добавить TLS"
1. Режим: Использовать текст.
2. Сертификат: вставить содержимое fullchain.pem.
3. Ключ: вставить содержимое privkey.pem.
4. Отключить SNI: выключено.
5. Разрешить небезопасное: выключено.
6. ACME: выключено.
7. ECH: выключено.

Откуда брать файлы для вставки:
- fullchain.pem: certbot/conf/live/fish-house.su/fullchain.pem
- privkey.pem: certbot/conf/live/fish-house.su/privkey.pem

Если используете режим "Использовать путь" в S-UI:
- указывайте путь внутри контейнера: /etc/letsencrypt/live/fish-house.su/fullchain.pem
- и путь к ключу: /etc/letsencrypt/live/fish-house.su/privkey.pem
- путь вида certbot/conf/... не работает, потому что это путь на хосте, а не в контейнере.

Важно после перевыпуска сертификата:
- Если выполнялся scripts/init-letsencrypt.sh или certbot renew/certonly, заново вставьте актуальные fullchain.pem и privkey.pem в TLS inbound VLESS.
- Причина: в режиме "Использовать текст" S-UI хранит PEM в конфиге inbound и не подхватывает изменения файлов автоматически.

Рекомендуемые параметры TLS:
- Min version: 1.2.
- Max version: 1.3.
- ALPN: h2,http/1.1.

## Настройка клиента
- Address: vless.fish-house.su.
- Port: 443.
- Protocol: VLESS.
- Transport: TCP.
- TLS: включен.
- SNI/ServerName: vless.fish-house.su.
- AllowInsecure: false.
- UUID: как в inbound S-UI.

## Проверка после сохранения
1. Убедиться, что inbound в S-UI активен и слушает 28889.
2. Проверить, что клиент использует именно vless.fish-house.su как SNI.
3. Проверить подключение клиента на 443/TCP.
4. Если сертификат недавно перевыпускался, заново вставить fullchain.pem/privkey.pem в TLS inbound.

## Частые ошибки
- SNI указан как fish-house.su или panel.fish-house.su: трафик уходит не в VLESS backend.
- Неверный UUID клиента.
- Сертификат не содержит vless.fish-house.su в SAN.
- На клиенте включен insecure режим и скрывает реальную TLS-проблему.
