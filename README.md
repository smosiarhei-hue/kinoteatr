# Кинотеатр (iOS)

iOS-приложение на SwiftUI: каталог фильмов (TMDB), торрент-стриминг через magnet-ссылки, воспроизведение в AVPlayer.

## Возможности
- Главная: популярные фильмы (discover TMDB) с бесконечной подгрузкой.
- Сортировка: популярность, рейтинг, голоса, дата выхода, сборы.
- Фильтры: жанр, год, минимальный рейтинг; поиск по названию.
- Нажатие на карточку → поиск magnet → буферизация → стрим.
- Плеер: статистика пиров/скорости/буфера, пауза/стоп.

## Настройка
1. TMDB API ключ: themoviedb.org → Settings → API (v3 auth key) → Настройки приложения.
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
