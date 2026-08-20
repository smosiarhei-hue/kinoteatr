import AVKit
import Foundation

@MainActor
final class TorrentPlayerService: ObservableObject {
    @Published var state: TorrentSessionState = .idle
    @Published var stats = TorrentStats()
    @Published var player: AVPlayer?
    @Published var errorMessage: String?

    private var engine: TorrentEngine?
    private let search = MagnetSearchService.shared
    private var statsTask: Task<Void, Never>?

    private func makeEngine() -> TorrentEngine {
        let url = AppSettings.shared.torrServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty {
            return TorrServerEngine(baseURL: url)
        }
        return StubTorrentEngine()
    }

    var isPlayable: Bool {
        if case .ready = state { return true }
        return false
    }

    func play(movie: Movie) async {
        await play(movie: movie, magnet: nil)
    }

    func play(movie: Movie, magnet: MagnetResult?) async {
        errorMessage = nil
        state = .searchingMagnet

        let candidate: MagnetResult
        if let magnet {
            candidate = magnet
        } else {
            let candidates = await search.search(movie: movie)
            guard let first = candidates.first else {
                fail("Не найдено magnet-ссылок для «\(movie.title)»")
                return
            }
            candidate = first
        }

        state = .resolvingMetadata
        statsTask?.cancel()

        let activeEngine = makeEngine()
        engine = activeEngine

        do {
            let url = try await activeEngine.startStream(magnet: candidate.magnet) { [weak self] snapshot in
                Task { @MainActor in
                    guard let self else { return }
                    self.stats = snapshot
                    if !self.isPlayable {
                        self.state = .downloading(progress: snapshot.progress)
                    }
                }
            }
            state = .ready(streamURL: url)
            let item = AVPlayerItem(url: url)
            let avPlayer = AVPlayer(playerItem: item)
            avPlayer.automaticallyWaitsToMinimizeStalling = true
            player = avPlayer
            avPlayer.play()
        } catch {
            fail(error.localizedDescription)
        }
    }

    func pause() async {
        player?.pause()
        await engine?.pause()
    }

    func resume() async {
        await engine?.resume()
        player?.play()
    }

    func stop() async {
        statsTask?.cancel()
        statsTask = nil
        player?.pause()
        player = nil
        await engine?.stop()
        engine = nil
        state = .idle
        stats = TorrentStats()
    }

    func dismissError() {
        errorMessage = nil
    }

    private func fail(_ message: String) {
        errorMessage = message
        state = .failed(message: message)
    }
}
