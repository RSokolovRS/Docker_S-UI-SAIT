# Клиентские профили для этого проекта

Этот файл содержит готовые параметры для клиентов под текущую серверную схему:
- HY2: домен hy2.fish-house.su, порт 443, транспорт UDP/QUIC.
- VLESS-TCP: домен vless.fish-house.su, порт 443, транспорт TCP + TLS.

Важно
- Сертификат сервера должен содержать SAN для hy2.fish-house.su и vless.fish-house.su.
- На клиенте не включать Insecure/Skip cert verify.
- Для VLESS обязательно указывать SNI: vless.fish-house.su.
- Для HY2 обязательно указывать SNI: hy2.fish-house.su.

## Универсальный шаблон HY2
- Type: Hysteria2
- Server: hy2.fish-house.su
- Port: 443
- Transport: UDP или QUIC
- TLS: On
- SNI: hy2.fish-house.su
- Allow insecure: Off
- Password: как в inbound S-UI
- Obfs: только если включен на сервере, и с тем же значением

## Универсальный шаблон VLESS-TCP
- Type: VLESS
- Server: vless.fish-house.su
- Port: 443
- Network: TCP
- TLS: On
- SNI: vless.fish-house.su
- Allow insecure: Off
- UUID: как в inbound S-UI
- Flow: обычно пусто (none), если отдельно не требуется другое

## v2rayN (Windows) — VLESS-TCP
1. Add profile -> VLESS.
2. Address: vless.fish-house.su.
3. Port: 443.
4. UUID: из S-UI.
5. Network: TCP.
6. TLS: включить.
7. SNI: vless.fish-house.su.
8. AllowInsecure: false.

## NekoBox (Android) — VLESS-TCP
1. New profile -> VLESS.
2. Server: vless.fish-house.su.
3. Port: 443.
4. UUID: из S-UI.
5. Transport: TCP.
6. TLS/Security: TLS.
7. Server Name (SNI): vless.fish-house.su.
8. Insecure: Off.

## NekoBox (Android) — HY2
1. New profile -> Hysteria2.
2. Server: hy2.fish-house.su.
3. Port: 443.
4. Password: из S-UI inbound HY2.
5. TLS: On.
6. SNI: hy2.fish-house.su.
7. Insecure: Off.
8. Obfs: только если включали на сервере.

## Streisand (iOS) — VLESS-TCP
1. Add node -> VLESS.
2. Host: vless.fish-house.su.
3. Port: 443.
4. UUID: из S-UI.
5. Transport: TCP.
6. TLS: On.
7. SNI: vless.fish-house.su.
8. Skip certificate verify: Off.

## Streisand (iOS) — HY2
1. Add node -> Hysteria2.
2. Host: hy2.fish-house.su.
3. Port: 443.
4. Password: из S-UI.
5. TLS: On.
6. SNI: hy2.fish-house.su.
7. Skip certificate verify: Off.

## Быстрая диагностика
- Не подключается HY2:
  - проверить DNS для hy2.fish-house.su;
  - проверить, что клиент использует UDP/QUIC;
  - проверить совпадение Password и Obfs.
- Не подключается VLESS:
  - проверить SNI именно vless.fish-house.su;
  - проверить UUID;
  - проверить, что TLS включен и Insecure выключен.
- Ошибка сертификата:
  - проверить SAN сертификата;
  - проверить дату и время на клиенте.

## Связанные документы
- HY2 настройки сервера и панели: HY2.md
- VLESS настройки сервера и панели: VLESS.md
- Общий проектный гайд: README.md
