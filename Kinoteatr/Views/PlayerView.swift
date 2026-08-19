import AVKit
import SwiftUI

struct PlayerView: View {
    let movie: Movie
    var magnet: MagnetResult?

    @EnvironmentObject private var playerService: TorrentPlayerService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch playerService.state {
                case .searchingMagnet, .resolvingMetadata:
                    bufferingOverlay(progress: 0)
                case .downloading(let progress):
                    bufferingOverlay(progress: progress)
                case .ready:
                    videoPlayer
                case .failed(let message):
                    failedOverlay(message: message)
                case .idle:
                    bufferingOverlay(progress: 0)
                }
            }
            .overlay(alignment: .top) { overlayHeader }
            .task {
                await playerService.stop()
                await playerService.play(movie: movie, magnet: magnet)
            }
            .onDisappear {
                Task { await playerService.stop() }
            }
            .alert("Ошибка", isPresented: .init(
                get: { playerService.errorMessage != nil },
                set: { if !$0 { playerService.dismissError() } }
            )) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(playerService.errorMessage ?? "")
            }
        }
    }

    private var videoPlayer: some View {
        VideoPlayer(player: playerService.player)
            .ignoresSafeArea()
            .onTapGesture(count: 1) {}
    }

    private func bufferingOverlay(progress: Double) -> some View {
        VStack(spacing: 16) {
            ProgressView(value: min(max(progress, 0), 1))
                .progressViewStyle(.linear)
                .tint(.orange)
                .frame(maxWidth: 260)
            Text(bufferingText)
                .font(.headline)
                .foregroundStyle(.white)
            statsView
        }
        .padding()
    }

    private func failedOverlay(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text(message)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button("Повторить") {
                Task {
                    await playerService.stop()
                    await playerService.play(movie: movie, magnet: magnet)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var bufferingText: String {
        switch playerService.state {
        case .searchingMagnet: return "Поиск magnet-ссылок…"
        case .resolvingMetadata: return "Получение метаданных…"
        case .downloading: return "Буферизация…"
        default: return "Подготовка…"
        }
    }

    private var statsView: some View {
        HStack(spacing: 16) {
            statItem(icon: "arrow.down.circle", value: formatBitrate(playerService.stats.downloadRate))
            statItem(icon: "person.3", value: "\(playerService.stats.peersConnected)")
            statItem(icon: "internaldrive", value: formatBytes(playerService.stats.bufferSize))
        }
    }

    private func statItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var overlayHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Text(movie.title)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.black.opacity(0.5), in: Capsule())
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func formatBitrate(_ bytes: Int64) -> String {
        if bytes == 0 { return "—" }
        let mbps = Double(bytes * 8) / 1_000_000
        return String(format: "%.1f Мбит/с", mbps)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
