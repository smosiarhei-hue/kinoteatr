import Foundation

struct MagnetResult: Identifiable {
    var id: String { magnet }
    let magnet: String
    let name: String
    let sizeBytes: Int64
    let seeds: Int

    var hasRussianAudio: Bool {
        let n = name.lowercased()
        let markers = [
            "дубляж", "дублированн", "полный дубляж",
            "закадров", "многоголос", "двухголос",
            "авторск", "любительск", "одноголос",
            "профессиональн", "проф. озвучка",
            "русская озвучка", "русский перевод", "на русском", "русски",
            "russian", "rus dub", "russian audio", "ru audio", "voice",
        ]
        return markers.contains { n.contains($0) }
    }

    var quality: String? {
        let n = name.lowercased()
        if n.contains("2160p") || n.contains("4k") || n.contains("uhd") { return "4K" }
        if n.contains("1080p") || n.contains("fullhd") { return "1080p" }
        if n.contains("720p") || n.contains("hd") { return "720p" }
        if n.contains("480p") { return "480p" }
        if n.contains("camrip") || n.contains("ts") || n.contains("cam") { return "CAM" }
        return nil
    }

    var source: String? {
        let n = name.lowercased()
        if n.contains("web-dl") || n.contains("webdl") { return "WEB-DL" }
        if n.contains("webrip") { return "WEBRip" }
        if n.contains("bluray") || n.contains("bdrip") || n.contains("bdr") { return "Blu-ray" }
        if n.contains("hdtv") { return "HDTV" }
        if n.contains("dvdrip") || n.contains("dvd") { return "DVD" }
        return nil
    }

    var audioLabel: String? {
        let n = name.lowercased()
        if n.contains("дубляж") || n.contains("дублированн") { return "Дубляж" }
        if n.contains("профессиональн") && n.contains("многоголос") { return "Проф. многоголосый" }
        if n.contains("многоголос") { return "Многоголосый" }
        if n.contains("двухголос") { return "Двухголосый" }
        if n.contains("закадров") { return "Закадровый" }
        if n.contains("авторск") { return "Авторский" }
        if n.contains("любительск") { return "Любительский" }
        if n.contains("одноголос") { return "Одноголосый" }
        if hasRussianAudio { return "RU озвучка" }
        return nil
    }
}

protocol MagnetProvider {
    var name: String { get }
    func search(movie: Movie, year: String?) async throws -> [MagnetResult]
}

struct DemoMagnetProvider: MagnetProvider {
    let name = "Demo"

    func search(movie: Movie, year: String?) async throws -> [MagnetResult] {
        try await Task.sleep(nanoseconds: 600_000_000)
        let hash = Array("0123456789abcdef")
        var h = ""
        for _ in 0..<40 { h.append(hash.randomElement()!) }
        let label = year.map { "\(movie.title) (\($0))" } ?? movie.title
        return [
            MagnetResult(
                magnet: "magnet:?xt=urn:btih:\(h)&dn=\(label.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")&tr=udp://tracker.opentrackr.org:1337/announce",
                name: "\(label) [1080p WEB-DL]",
                sizeBytes: 4_200_000_000,
                seeds: 127,
            )
        ]
    }
}

struct JackettMagnetProvider: MagnetProvider {
    let name = "Jackett"
    let baseURL: String

    func search(movie: Movie, year: String?) async throws -> [MagnetResult] {
        // Трекеры индексируются по оригинальным (английским) названиям:
        // русское название из TMDB почти всегда даёт 0 результатов. Сначала
        // ищем по оригиналу, при пустом результате пробуем локальное название.
        let original = movie.originalTitle ?? movie.title
        var results = try await searchTitle(original, year: year)
        if results.isEmpty && original != movie.title {
            print("[MagnetSearch] Jackett: по оригинальному названию пусто, пробую «\(movie.title)»")
            results = try await searchTitle(movie.title, year: year)
        }
        return results
    }

    private func searchTitle(_ movie: String, year: String?) async throws -> [MagnetResult] {
        let query = year.map { "\(movie) \($0)" } ?? movie
        var comps = URLComponents(string: baseURL)
        comps?.queryItems = [URLQueryItem(name: "Query", value: query)]
        guard let url = comps?.url else { return [] }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            print("[MagnetSearch] Jackett: HTTP \(String(describing: (response as? HTTPURLResponse)?.statusCode)) — проверьте URL и API-ключ")
            return []
        }

        struct Row: Codable {
            let Title: String?
            let MagnetUri: String?
            let Size: Int64?
            let Seeders: Int?
        }
        struct Payload: Codable { let Results: [Row] }
        let payload = try? JSONDecoder().decode(Payload.self, from: data)
        return (payload?.Results ?? []).compactMap { row in
            guard let magnet = row.MagnetUri, magnet.hasPrefix("magnet:") else { return nil }
            return MagnetResult(magnet: magnet,
                                name: row.Title ?? movie,
                                sizeBytes: row.Size ?? 0,
                                seeds: row.Seeders ?? 0)
        }
    }
}

struct SearchOutcome {
    let results: [MagnetResult]
    let diagnostics: [String]
}

actor MagnetSearchService {
    static let shared = MagnetSearchService()

    private func makeProviders() -> [MagnetProvider] {
        var list: [MagnetProvider] = []
        let jackett = AppSettings.shared.jackettURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let torr = AppSettings.shared.torrServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !jackett.isEmpty {
            list.append(JackettMagnetProvider(baseURL: jackett))
        }
        if torr.isEmpty {
            // Демо-ссылки воспроизводятся только демо-движком (StubTorrentEngine),
            // поэтому добавляем их, только когда TorrServer не настроен.
            list.append(DemoMagnetProvider())
        }
        return list
    }

    var providers: [MagnetProvider] { makeProviders() }

    func reloadProviders() {}

    func search(movie: Movie) async -> SearchOutcome {
        reloadProviders()
        var all: [MagnetResult] = []
        var diagnostics: [String] = []
        let active = providers
        if active.isEmpty {
            diagnostics.append("Источники не настроены: задайте URL Jackett (и/или TorrServer) в Настройках.")
        }
        for provider in active {
            do {
                let found = try await provider.search(movie: movie, year: movie.releaseYear)
                all.append(contentsOf: found)
                if found.isEmpty {
                    diagnostics.append("\(provider.name): вернул 0 раздач по запросу.")
                } else {
                    diagnostics.append("\(provider.name): найдено \(found.count) раздач.")
                }
            } catch {
                diagnostics.append("\(provider.name): ошибка — \(error.localizedDescription)")
            }
        }
        var seen = Set<String>()
        let unique = all.filter { seen.insert($0.magnet).inserted }
        return SearchOutcome(results: Self.rank(unique), diagnostics: diagnostics)
    }

    static func rank(_ results: [MagnetResult]) -> [MagnetResult] {
        let prefer = AppSettings.shared.preferRussianAudio
        let sorted: [MagnetResult]
        if prefer {
            sorted = results.sorted {
                if $0.hasRussianAudio != $1.hasRussianAudio {
                    return $0.hasRussianAudio
                }
                return $0.seeds > $1.seeds
            }
        } else {
            sorted = results.sorted { $0.seeds > $1.seeds }
        }
        // Если в настройках выбрано конкретное качество («480p/720p/1080p/4K»),
        // подходящие раздачи поднимаем в начало списка (остальные тоже видны).
        guard let preferred = qualityPreference() else { return sorted }
        var matching: [MagnetResult] = []
        var rest: [MagnetResult] = []
        for r in sorted {
            if r.quality == preferred { matching.append(r) } else { rest.append(r) }
        }
        return matching + rest
    }

    private static func qualityPreference() -> String? {
        let q = AppSettings.shared.defaultQuality
        return ["480p", "720p", "1080p", "4K"].contains(q) ? q : nil
    }
}
