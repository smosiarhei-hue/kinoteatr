import Foundation

struct MagnetResult {
    let magnet: String
    let name: String
    let sizeBytes: Int64
    let seeds: Int

    var hasRussianAudio: Bool {
        let n = name.lowercased()
        let markers = [
            "дубляж", "дублирован", "профессиональн", "многоголосый",
            "многоголос", "русская озвучка", "русская дорожка", "русски",
            "russian", "rus dub", "line", "лицензия", "voice", " озв",
        ]
        return markers.contains { n.contains($0) }
    }
}

protocol MagnetProvider {
    var name: String { get }
    func search(movie: String, year: String?) async throws -> [MagnetResult]
}

struct DemoMagnetProvider: MagnetProvider {
    let name = "Demo"

    func search(movie: String, year: String?) async throws -> [MagnetResult] {
        try await Task.sleep(nanoseconds: 600_000_000)
        let hash = Array("0123456789abcdef")
        var h = ""
        for _ in 0..<40 { h.append(hash.randomElement()!) }
        let label = year.map { "\(movie) (\($0))" } ?? movie
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

    func search(movie: String, year: String?) async throws -> [MagnetResult] {
        let query = year.map { "\(movie) \($0)" } ?? movie
        var comps = URLComponents(string: baseURL)
        comps?.queryItems = [URLQueryItem(name: "Query", value: query)]
        guard let url = comps?.url else { return [] }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

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

actor MagnetSearchService {
    static let shared = MagnetSearchService()

    private var providers: [MagnetProvider] = {
        var list: [MagnetProvider] = []
        let jackett = AppSettings.shared.jackettURL
        if !jackett.isEmpty { list.append(JackettMagnetProvider(baseURL: jackett)) }
        list.append(DemoMagnetProvider())
        return list
    }()

    func reloadProviders() {
        var list: [MagnetProvider] = []
        let jackett = AppSettings.shared.jackettURL
        if !jackett.isEmpty { list.append(JackettMagnetProvider(baseURL: jackett)) }
        list.append(DemoMagnetProvider())
        providers = list
    }

    func search(movie: Movie) async -> [MagnetResult] {
        reloadProviders()
        for provider in providers {
            if let results = try? await provider.search(movie: movie.title, year: movie.releaseYear),
               !results.isEmpty {
                return Self.rank(results)
            }
        }
        return []
    }

    static func rank(_ results: [MagnetResult]) -> [MagnetResult] {
        let prefer = AppSettings.shared.preferRussianAudio
        guard prefer else {
            return results.sorted { $0.seeds > $1.seeds }
        }
        return results.sorted {
            if $0.hasRussianAudio != $1.hasRussianAudio {
                return $0.hasRussianAudio
            }
            return $0.seeds > $1.seeds
        }
    }
}
