import Foundation

final class TorrServerEngine: TorrentEngine {
    private let baseURL: URL
    private var currentHash: String?
    private var pollTask: Task<Void, Never>?

    init(baseURL: String) {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/") { trimmed.removeLast() }
        self.baseURL = URL(string: trimmed)!
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

        let torr = try Self.decoder.decode(TorrTorrent.self, from: data)
        guard let hash = torr.hash, !hash.isEmpty else { throw TorrentEngineError.backendNotLinked }
        currentHash = hash

        var fileStats = torr.file_stats ?? []
        if fileStats.isEmpty {
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if let refreshed = await fetchTorrent(hash: hash), let fs = refreshed.file_stats, !fs.isEmpty {
                    fileStats = fs
                    break
                }
            }
        }

        let videoFiles = fileStats.filter { Self.isVideoFile($0.path ?? "") }
        let chosen = videoFiles.max(by: { ($0.length ?? 0) < ($1.length ?? 0) })
        let fileIndex = chosen?.id ?? 1
        let totalSize = fileStats.reduce(Int64(0)) { $0 + ($1.length ?? 0) }

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard let self, let hash = self.currentHash else { break }
                if let torrent = await self.fetchTorrent(hash: hash) {
                    let stats = Self.makeStats(from: torrent, totalSize: totalSize)
                    onStats(stats)
                }
            }
        }

        let streamURL = baseURL
            .appendingPathComponent("stream")
            .appendingPathComponent(hash)
            .appendingPathComponent("\(fileIndex)")
        var comps = URLComponents(url: streamURL, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "play", value: nil)]
        return comps?.url ?? streamURL
    }

    private static func isVideoFile(_ path: String) -> Bool {
        let lower = path.lowercased()
        return [".mp4", ".mkv", ".avi", ".mov", ".m4v", ".ts"].contains { lower.hasSuffix($0) }
    }

    private func fetchTorrent(hash: String) async -> TorrTorrent? {
        let url = baseURL.appendingPathComponent("torrents")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["action": "get", "hash": hash])
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return try? Self.decoder.decode(TorrTorrent.self, from: data)
    }

    private static func makeStats(from torrent: TorrTorrent, totalSize: Int64) -> TorrentStats {
        let preloaded = torrent.preloaded_bytes ?? 0
        let size = totalSize > 0 ? totalSize : (torrent.data_size ?? 0)
        let progress = size > 0 ? Double(preloaded) / Double(size) : 0
        return TorrentStats(
            progress: min(progress, 1.0),
            downloadRate: Int64(torrent.download_speed ?? 0),
            uploadRate: Int64(torrent.upload_speed ?? 0),
            peersConnected: torrent.active_peers ?? 0,
            bufferSize: preloaded
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

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
}

struct TorrTorrent: Codable {
    let hash: String?
    let stat: Int?
    let stat_string: String?
    let title: String?
    let data_size: Int64?
    let preloaded_bytes: Int64?
    let download_speed: Double?
    let upload_speed: Double?
    let total_peers: Int?
    let active_peers: Int?
    let connected_seeders: Int?
    let file_stats: [TorrFileStat]?
}

struct TorrFileStat: Codable {
    let id: Int?
    let path: String?
    let length: Int64?
}
