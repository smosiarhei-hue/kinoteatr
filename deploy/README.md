# Развёртывание серверной части (VPS / всегда включённый ПК)

Поднимает Jackett (поиск раздач) и TorrServer (стриминг) в Docker — работает
круглосуточно, независимо от телефона и ноутбука.

## Быстрый старт
1. Установите Docker (https://docs.docker.com/engine/install/).
2. Скопируйте эту папку на сервер: `deploy/`
3. Запустите:
   ```bash
   docker compose up -d
   ```
4. Откройте Jackett: `http://<IP-сервера>:9117` — задайте пароль интерфейса,
   скопируйте полный URL из «Copy results API URL» (All Indexers).
5. Проверьте TorrServer: `http://<IP-сервера>:8090` — должен открыться интерфейс.

## Что вписать в приложение (Настройки → Режим разработчика)
- Jackett: `http://<IP-сервера>:9117/api/v2.0/indexers/all/results?apikey=<ключ из шага 4>`
- TorrServer: `http://<IP-сервера>:8090` (+ пароль TorrServer, если задан в его настройках)

## Постоянная ссылка на свежий IPA
Каждый пуш в репозиторий и каждую ночь (03:00 UTC) GitHub Actions собирает и
публикует сборку в Release «latest»:
- подписанный: https://github.com/smosiarhei-hue/kinoteatr/releases/latest/download/Kinoteatr-signed.ipa
- без подписи: https://github.com/smosiarhei-hue/kinoteatr/releases/latest/download/Kinoteatr-unsigned.ipa

Ссылка всегда ведёт на свежую сборку. Устанавливайте её через GBox/eSign.

## Безопасность
- Открывайте порты 9117/8090 наружу только если уверены в необходимости;
  Jackett защищён паролем интерфейса и API-ключом, TorrServer — паролем.
- VPS для торрент-трафика выбирайте с учётом местного законодательства.