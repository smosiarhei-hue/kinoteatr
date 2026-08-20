import Foundation

final class TorrServerEngine: TorrentEngine {
    private let baseURL: URL
    private var currentHash: String?
    private var pollTask: Task<Void, Never>?

    init(baseURL: String) {
        self.baseURL = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines))!
    }

    func startStream(magnet: String, onStats: @escaping (TorrentStats) -> Void) async throws -> URL {
        guard magnet.hasPrefix("magnet:") else { throw TorrentEngineError.magnetInvalid }

        let addURL = baseURL.appendingPathComponent("torrents")
        var request = URLRequest(url: addURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["link": magnet, "title": "Fluxo", "poster": ""]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TorrentEngineError.backendNotLinked
        }

        struct TorrResponse: Codable {
            let hash: String?
            let stat: Int?
            let file_stats: [FileStat]?
            struct FileStat: Codable {
                let id: Int?
                let path: String?
                let length: Int64?
            }
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let torr = try decoder.decode(TorrResponse.self, from: data)
        guard let hash = torr.hash else { throw TorrentEngineError.backendNotLinked }
        currentHash = hash

        let fileIndex = torr.file_stats?
            .filter { ($0.path ?? "").lowercased().hasSuffix(".mp4") || ($0.path ?? "").lowercased().hasSuffix(".mkv") || ($0.path ?? "").lowercased().hasSuffix(".avi") }
            .max(by: { ($0.length ?? 0) < ($1.length ?? 0) })?.id ?? 1

        let totalSize = torr.file_stats?.reduce(Int64(0)) { $0 + ($1.length ?? 0) } ?? 0

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard let self, let hash = self.currentHash else { break }
                if let stats = await self.fetchStats(hash: hash, totalSize: totalSize) {
                    onStats(stats)
                }
            }
        }

        let streamURL = baseURL.appendingPathComponent("stream").appendingPathComponent(hash).appendingPathComponent("\(fileIndex)")
        var comps = URLComponents(url: streamURL, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "play", value: "")]
        return comps?.url ?? streamURL
    }

    private func fetchStats(hash: String, totalSize: Int64) async -> TorrentStats? {
        let url = baseURL.appendingPathComponent("torrents")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["action": "get", "hash": hash])
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }

        struct StatResp: Codable {
            let active_peers: Int?
            let total_peers: Int?
            let download_speed: Double?
            let upload_speed: Double?
            let downloaded: Int64?
        }
        guard let stat = try? JSONDecoder().decode(StatResp.self, from: data) else { return nil }
        let downloaded = stat.downloaded ?? 0
        let progress = totalSize > 0 ? Double(downloaded) / Double(totalSize) : 0
        return TorrentStats(
            progress: progress,
            downloadRate: Int64(stat.download_speed ?? 0),
            uploadRate: Int64(stat.upload_speed ?? 0),
            peersConnected: stat.active_peers ?? 0,
            bufferSize: downloaded
        )
    }

    func pause() async {
        pollTask?.cancel()
    }

    func resume() async {}

    func stop() async {
        pollTask?.cancel()
        pollTask = nil
        if let hash = currentHash {
            let url = baseURL.appendingPathComponent("torrents")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["action": "rem", "hash": hash])
            _ = try? await URLSession.shared.data(for: request)
        }
        currentHash = nil
    }
}
