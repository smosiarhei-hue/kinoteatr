import AVKit
import Foundation

@MainActor
final class TorrentPlayerService: ObservableObject {
    @Published var state: TorrentSessionState = .idle
    @Published var stats = TorrentStats()
    @Published var player: AVPlayer?
    @Published var errorMessage: String?

    private let engine: TorrentEngine
    private let search = MagnetSearchService.shared
    private var statsTask: Task<Void, Never>?

    init(engine: TorrentEngine = StubTorrentEngine()) {
        self.engine = engine
    }

    var isPlayable: Bool {
        if case .ready = state { return true }
        return false
    }

    func play(movie: Movie) async {
        errorMessage = nil
        state = .searchingMagnet

        let candidates = await search.search(movie: movie)
        guard let candidate = candidates.first else {
            fail("Не найдено magnet-ссылок для «\(movie.title)»")
            return
        }

        state = .resolvingMetadata
        statsTask?.cancel()
        statsTask = Task { [weak self] in
            let fake = TorrentStats(downloadRate: 6_500_000, uploadRate: 120_000, peersConnected: 41)
            while !Task.isCancelled {
                await MainActor.run { self?.stats = fake }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        do {
            let url = try await engine.startStream(magnet: candidate.magnet) { [weak self] snapshot in
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
        await engine.pause()
    }

    func resume() async {
        await engine.resume()
        player?.play()
    }

    func stop() async {
        statsTask?.cancel()
        statsTask = nil
        player?.pause()
        player = nil
        await engine.stop()
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
