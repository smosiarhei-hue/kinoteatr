# Кинотеатр (iOS)

iOS-приложение на SwiftUI: каталог фильмов (TMDB), торрент-стриминг через magnet-ссылки, воспроизведение в AVPlayer.

## Возможности
- Главная: популярные фильмы (discover TMDB) с бесконечной подгрузкой.
- Сортировка: популярность, рейтинг, голоса, дата выхода, сборы.
- Фильтры: жанр, год, минимальный рейтинг; поиск по названию.
- Нажатие на карточку → поиск magnet → буферизация → стрим.
- Плеер: статистика пиров/скорости/буфера, пауза/стоп.

## Настройка
1. TMDB API ключ: themoviedb.org → Settings → API → Настройки приложения. Поддерживается v3 API key и v4 Read Access Token.
2. Реальные торренты: поднять Jackett и вставить URL в Настройки (`.../api/v2.0/indexers/all/results?apikey=...`). Без Jackett работает Demo-провайдер (демо-magnet'ы).
3. Проект: `xcodegen generate` (или открыть `Kinoteatr/*.swift` вручную в Xcode: File → New → Project → создать таргет и добавить папку `Kinoteatr/`).

## Торрент-движок
Архитектура: `TorrentEngine` (протокол) → `StubTorrentEngine` (демо: имитация загрузки + локальный HTTP-стрим сгенерированного mp4 через AVAssetWriter).
Для продакшена подключить SPM-пакет, реализующий `TorrentEngine` (libtorrent-обёртка), и передать его в `TorrentPlayerService`.

## Структура
```
Kinoteatr/
  App/            — точка входа
  Models/         — Movie, Genre, Settings, кэш
  Networking/     — TMDBAPI (discover/search/genres)
  Torrent/        — движок, magnet-провайдеры, локальный сервер, демо-видео
  Player/         — TorrentPlayerService (состояния сессии)
  ViewModels/     — каталог, фильтры, пагинация, поиск
  Views/          — табы, главная, карточки, фильтры, плеер, настройки
  Support/        — Info.plist, Assets
project.yml       — манифест XcodeGen
```

## Известные ограничения
- iOS не пускает полноценный BitTorrent-клиент без замены движка; `TorrentEngine` — точка расширения.
- App Store может отклонить торрент-фичи; для личного использования (side-load) подходит.

## Установка через GBox
- После изменений нужно пересобрать IPA через GitHub Actions или Xcode на macOS: исходный dist/*.ipa уже собран из старого кода.
- Иконка хранится в полном наборе iOS-размеров в Kinoteatr/Support/Assets.xcassets/AppIcon.appiconset, поэтому при новой сборке GBox должен показывать корректную иконку.

## Сборка и подпись (GitHub Actions)
Workflow `.github/workflows/build.yml` запускается на пуше в `master`, на теге `v*` и вручную (`workflow_dispatch`).

Порядок шагов:
1. Прогоняются тесты скриптов доставки: `python3 -m unittest discover -s .github/scripts`.
2. Версия считается из `github.run_number` и подставляется в `project.yml` и `Kinoteatr/Support/Info.plist`.
3. Секреты `APPLE_CERT_P12`, `APPLE_CERT_PASSWORD`, `APPLE_PROFILE` импортируются в отдельный keychain, из provisioning profile извлекаются UUID / Team ID / Bundle ID, а `patch_project_signing.py` приводит `project.yml` к этим значениям. Если секретов нет — сборка идёт unsigned и шаги подписи пропускаются.
4. `xcodebuild` собирает приложение, затем `codesign` переподписывает бандл с entitlements из профиля, и `codesign --verify` проверяет подпись.
5. Готовый IPA выкладывается в OTA: `deploy_ota_pages.py` кладёт `Kinoteatr.ipa` и `manifest.plist` в ветку `gh-pages` (сайт https://smosiarhei-hue.github.io/kinoteatr/).
6. При наличии `TELEGRAM_BOT_TOKEN` и `TELEGRAM_CHAT_ID` IPA отправляется в Telegram-чат (`send_ipa_telegram.py`). Недоставка не роняет сборку.

Скрипты в `.github/scripts/` покрыты тестами: `patch_project_signing`, `send_ipa_telegram`, `deploy_ota_pages`.

