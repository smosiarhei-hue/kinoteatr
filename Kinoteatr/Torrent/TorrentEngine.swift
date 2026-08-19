import Foundation

enum TorrentSessionState: Equatable {
    case idle
    case searchingMagnet
    case resolvingMetadata
    case downloading(progress: Double)
    case ready(streamURL: URL)
    case failed(message: String)

    static func == (lhs: TorrentSessionState, rhs: TorrentSessionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.searchingMagnet, .searchingMagnet),
             (.resolvingMetadata, .resolvingMetadata): return true
        case let (.downloading(a), .downloading(b)): return a == b
        case let (.ready(a), .ready(b)): return a == b
        case let (.failed(a), .failed(b)): return a == b
        default: return false
        }
    }
}

struct TorrentStats {
    var progress: Double = 0
    var downloadRate: Int64 = 0
    var uploadRate: Int64 = 0
    var peersConnected: Int = 0
    var bufferSize: Int64 = 0
}

protocol TorrentEngine {
    func startStream(magnet: String, onStats: @escaping (TorrentStats) -> Void) async throws -> URL
    func pause() async
    func resume() async
    func stop() async
}

enum TorrentEngineError: LocalizedError {
    case backendNotLinked
    case magnetInvalid
    case bufferTimeout

    var errorDescription: String? {
        switch self {
        case .backendNotLinked:
            return "Торрент-движок не подключён. Добавь libtorrent-streamer (см. README)."
        case .magnetInvalid:
            return "Некорректная magnet-ссылка."
        case .bufferTimeout:
            return "Не удалось набрать буфер для воспроизведения."
        }
    }
}
