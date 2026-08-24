import Foundation

final class TorrServerEngine: TorrentEngine {
    private let baseURL: URL
    private var currentHash: String?
    private var pollTask: Task<Void, Never>?

    init(baseURL: String) throws {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let url = URL(string: trimmed), !trimmed.isEmpty else {
            throw TorrentEngineError.invalidServerURL
        }
        self.baseURL = url
    }

    private var password: String {
        AppSettings.shared.torrServerPassword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func startStream(magnet: String, onStats: @escaping (TorrentStats) -> Void) async throws -> URL {
        guard magnet.hasPrefix("magnet:") else { throw TorrentEngineError.magnetInvalid }

        let addURL = baseURL.appendingPathComponent("torrents")
        var request = URLRequest(url: addURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["link": magnet, "title": "Fluxo", "poster": ""]
        if !password.isEmpty { body["password"] = password }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TorrentEngineError.backendNotLinked
        }
        guard let torr = try? Self.decoder.decode(TorrTorrent.self, from: data) else {
            throw TorrentEngineError.backendNotLinked
        }
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
        guard !fileStats.isEmpty else {
            throw TorrentEngineError.metadataTimeout
        }

        let videoFiles = fileStats.filter { Self.isVideoFile($0.path ?? "") }
        // iOS AVPlayer нативно умеет mp4/m4v/mov (и ts). mkv/avi/webm не
        // воспроизводятся: берём их только если играбельных файлов нет вовсе.
        let playable = videoFiles.filter { Self.isPlayableByAVPlayer($0.path ?? "") }
        let candidates = playable.isEmpty ? videoFiles : playable
        guard let chosen = candidates.max(by: { ($0.length ?? 0) < ($1.length ?? 0) }) else {
            throw TorrentEngineError.metadataTimeout
        }
        print("[TorrServer] выбран файл: \(chosen.path ?? "?") (\(chosen.length ?? 0) байт)")
        let fileIndex = chosen.id
        let totalSize = fileStats.reduce(Int64(0)) { $0 + ($1.length ?? 0) }

        // Ждём старта загрузки до 15 секунд: если байты не пошли и пиров нет —
        // у раздачи нет сидов/трекеров, сразу показываем понятную ошибку.
        for _ in 0..<15 {
            if let t = await fetchTorrent(hash: hash) {
                let progressed = (t.preloaded_bytes ?? 0) > 0 || (t.download_speed ?? 0) > 0
                let hasPeers = (t.total_peers ?? 0) > 0
                if progressed || hasPeers || (t.stat ?? 0) >= 3 { break }
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        if let t = await fetchTorrent(hash: hash) {
            let progressed = (t.preloaded_bytes ?? 0) > 0 || (t.download_speed ?? 0) > 0
            if !progressed && (t.total_peers ?? 0) == 0 && (t.stat ?? 0) < 3 {
                throw TorrentEngineError.noPeers
            }
        }

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

        // iOS не играет mkv/avi/webm нативно. Для таких файлов берём HLS-транскод
        // gst-сборки TorrServer (master.m3u8 играется AVPlayer'ом), для
        // mp4/m4v/mov/ts — прямой стрим. Форматы URL проверены против MatriX.143.
        let streamURL: URL?
        if Self.isPlayableByAVPlayer(chosen.path ?? "") {
            let pathName = (chosen.path ?? "").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            var comps = URLComponents(string: baseURL.absoluteString + "/stream/" + pathName)
            comps?.queryItems = [
                URLQueryItem(name: "link", value: hash),
                URLQueryItem(name: "index", value: "\(fileIndex)"),
                URLQueryItem(name: "play", value: nil),
            ]
            streamURL = comps?.url
        } else {
            let gstURL = baseURL
                .appendingPathComponent("gst")
                .appendingPathComponent(hash)
                .appendingPathComponent("master.m3u8")
            var comps = URLComponents(url: gstURL, resolvingAgainstBaseURL: false)
            comps?.queryItems = [
                URLQueryItem(name: "index", value: "\(fileIndex)"),
                URLQueryItem(name: "audio", value: "0"),
            ]
            streamURL = comps?.url
        }
        guard streamURL != nil else { throw TorrentEngineError.invalidServerURL }
        return streamURL!
    }

    private static func isVideoFile(_ path: String) -> Bool {
        let lower = path.lowercased()
        return [".mp4", ".mkv", ".avi", ".mov", ".m4v", ".ts", ".webm"].contains { lower.hasSuffix($0) }
    }

    private static func isPlayableByAVPlayer(_ path: String) -> Bool {
        let lower = path.lowercased()
        return [".mp4", ".m4v", ".mov", ".ts"].contains { lower.hasSuffix($0) }
    }

    private func fetchTorrent(hash: String) async -> TorrTorrent? {
        let url = baseURL.appendingPathComponent("torrents")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["action": "get", "hash": hash]
        if !password.isEmpty { body["password"] = password }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return try? Self.decoder.decode(TorrTorrent.self, from: data)
    }

    private static func makeStats(from torrent: TorrTorrent, totalSize: Int64) -> TorrentStats {
        // MatriX.143 не отдаёт preloaded/download_speed/active_peers.
        // Прогресс оцениваем по stat: 3 = раздача качается. Пиры — total_peers.
        let working = (torrent.stat ?? 0) >= 3
        return TorrentStats(
            progress: working ? 1.0 : 0,
            downloadRate: 0,
            uploadRate: 0,
            peersConnected: torrent.total_peers ?? 0,
            bufferSize: working ? totalSize : 0
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
            var body: [String: Any] = ["action": "rem", "hash": hash]
            if !password.isEmpty { body["password"] = password }
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
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
    let pending_peers: Int?
    let torrent_size: Int64?
    let active_peers: Int?
    let connected_seeders: Int?
    let file_stats: [TorrFileStat]?
}

struct TorrFileStat: Codable {
    let id: Int?
    let path: String?
    let length: Int64?
}