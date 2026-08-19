import Foundation

final class StubTorrentEngine: TorrentEngine {
    private let ticker = DispatchQueue(label: "torrent.stub.ticker")
    private var cancelled = false
    private var paused = false
    private var server: LocalHTTPServer?

    func startStream(magnet: String, onStats: @escaping (TorrentStats) -> Void) async throws -> URL {
        cancelled = false
        guard magnet.hasPrefix("magnet:") else { throw TorrentEngineError.magnetInvalid }

        let fileURL = Bundle.main.url(forResource: "sample", withExtension: "mp4")
            ?? (await DemoVideoFactory.ensureSampleVideo())
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else {
            throw TorrentEngineError.backendNotLinked
        }

        let total = fileSize(fileURL)
        var downloaded: Int64 = 0
        var progress = 0.0

        repeat {
            try await Task.sleep(nanoseconds: 120_000_000)
            guard !cancelled else { throw CancellationError() }
            guard !paused else { continue }
            downloaded = min(downloaded + total / 40 + 1_048_576, total)
            progress = Double(downloaded) / Double(total)
            let stats = TorrentStats(progress: progress,
                                     downloadRate: 6_000_000,
                                     uploadRate: 200_000,
                                     peersConnected: 48,
                                     bufferSize: downloaded)
            onStats(stats)
        } while progress < 0.5 && !cancelled

        guard !cancelled else { throw CancellationError() }

        let server = LocalHTTPServer(folder: fileURL.deletingLastPathComponent(), port: 0)
        try server.start()
        self.server = server
        return server.streamURL(for: fileURL.lastPathComponent)
    }

    func pause() async { paused = true }

    func resume() async { paused = false }

    func stop() async {
        cancelled = true
        try? server?.stop()
        server = nil
    }

    private func fileSize(_ url: URL) -> Int64 {
        let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        return (attrs[.size] as? NSNumber)?.int64Value ?? 2_000_000_000
    }
}
