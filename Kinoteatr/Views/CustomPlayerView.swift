import AVFoundation
import SwiftUI

/// Свой плеер: стандартный AVPlayerLayer (AVKit/AVFoundation, iOS 27-совместимый)
/// + собственные контролы: play/pause, слайдер перемотки, ±10 секунд.
struct CustomPlayerView: View {
    let player: AVPlayer?

    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var controlsVisible = true
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0
    @State private var hideTask: Task<Void, Never>?

    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CustomPlayerLayer(player: player)
                .ignoresSafeArea()

            if controlsVisible {
                controlsOverlay
            }

            if !isPlaying && !isScrubbing {
                bigPlayButton
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleControls()
        }
        .onReceive(ticker) { _ in
            updatePlaybackState()
        }
        .onAppear {
            scheduleHide()
        }
        .onDisappear {
            hideTask?.cancel()
        }
    }

    // MARK: - Оверлей контролов

    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            controlBar
        }
        .transition(.opacity)
    }

    private var controlBar: some View {
        VStack(spacing: 10) {
            Slider(value: Binding(
                get: { isScrubbing ? scrubTime : currentTime },
                set: { value in
                    isScrubbing = true
                    scrubTime = value
                }
            ), in: 0...max(duration, 1)) { editing in
                if !editing {
                    seek(to: scrubTime)
                    isScrubbing = false
                } else {
                    scheduleHide(seconds: 6)
                }
            }
            .tint(.orange)
            .padding(.horizontal, 16)

            HStack {
                Text(formatTime(currentTime))
                Spacer()
                HStack(spacing: 28) {
                    Button { seek(by: -10) } label: {
                        Image(systemName: "gobackward.10").font(.title2)
                    }
                    Button { togglePlay() } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                    }
                    Button { seek(by: 10) } label: {
                        Image(systemName: "goforward.10").font(.title2)
                    }
                }
                Spacer()
                Text(formatTime(duration))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .padding(.vertical, 14)
        .background(.black.opacity(0.55))
    }

    private var bigPlayButton: some View {
        Button {
            togglePlay()
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(.black.opacity(0.45), in: Circle())
        }
        .transition(.opacity)
    }

    // MARK: - Логика

    private func updatePlaybackState() {
        guard let player else { return }
        isPlaying = player.timeControlStatus == .playing
        guard let item = player.currentItem else { return }
        let d = item.duration.seconds
        if d.isFinite && d > 0 { duration = d }
        let t = player.currentTime().seconds
        if t.isFinite && t >= 0 { currentTime = t }
        if !isScrubbing {
            scrubTime = currentTime
        }
    }

    private func togglePlay() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
        isPlaying = player.timeControlStatus == .playing
        scheduleHide()
    }

    private func seek(by seconds: Double) {
        guard let player, let item = player.currentItem else { return }
        let target = player.currentTime().seconds + seconds
        let clamped = min(max(target, 0), item.duration.seconds)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
        scheduleHide()
    }

    private func seek(to seconds: Double) {
        guard let player, let item = player.currentItem else { return }
        let clamped = min(max(seconds, 0), item.duration.seconds)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
        scheduleHide()
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible.toggle()
        }
        if controlsVisible { scheduleHide() }
    }

    private func scheduleHide(seconds: Double = 3.5) {
        hideTask?.cancel()
        guard player?.timeControlStatus == .playing || controlsVisible == false else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                controlsVisible = false
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

/// AVPlayerLayer в UIViewRepresentable — «стандартный» слой проигрывания iOS.
struct CustomPlayerLayer: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> PlayerLayerContainer {
        let view = PlayerLayerContainer()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerLayerContainer, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

final class PlayerLayerContainer: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspect
        backgroundColor = .black
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }
}