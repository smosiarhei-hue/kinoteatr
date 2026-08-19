import SwiftUI

struct TorrentPickerView: View {
    let movie: Movie
    let onSelect: (MagnetResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var results: [MagnetResult] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Поиск раздач…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    ContentUnavailableView {
                        Label("Раздач не найдено", systemImage: "magnifyingglass")
                    } description: {
                        Text("Для «\(movie.title)» ничего не нашлось. Проверьте Jackett в настройках.")
                    }
                } else {
                    List(results) { result in
                        Button {
                            choose(result)
                        } label: {
                            row(result)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Выберите раздачу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
            }
            .task { await load() }
        }
        .preferredColorScheme(.dark)
    }

    private func load() async {
        results = await MagnetSearchService.shared.search(movie: movie)
        isLoading = false
    }

    private func choose(_ result: MagnetResult) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onSelect(result)
        }
    }

    private func row(_ result: MagnetResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
            HStack(spacing: 12) {
                Label(ByteCountFormatter.string(fromByteCount: result.sizeBytes, countStyle: .file),
                      systemImage: "internaldrive")
                Label("\(result.seeds)", systemImage: "arrow.down.circle")
                if result.hasRussianAudio {
                    Text("RU озвучка")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.25)))
                        .foregroundStyle(.orange)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.orange)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
