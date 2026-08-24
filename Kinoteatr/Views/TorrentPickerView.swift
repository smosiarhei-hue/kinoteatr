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
                } else if searchUnavailable {
                    ContentUnavailableView {
                        Label("Не настроен поиск раздач", systemImage: "magnifyingglass")
                    } description: {
                        Text(searchUnavailableMessage)
                    }
                } else if results.isEmpty {
                    ContentUnavailableView {
                        Label("Ничего не найдено", systemImage: "magnifyingglass")
                    } description: {
                        Text("Для \(movie.title) раздач не найдено. Проверьте Jackett или попробуйте другой фильм.")
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
            .navigationTitle("Выбор раздачи · \(results.count)")
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

    private var searchUnavailable: Bool {
        let jackett = AppSettings.shared.jackettURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let torr = AppSettings.shared.torrServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return jackett.isEmpty && !torr.isEmpty
    }

    private var searchUnavailableMessage: String {
        "TorrServer настроен, но источник magnet-ссылок (Jackett) не задан.\n\nДобавьте URL Jackett в Настройках (Режим разработчика) или очистите адрес TorrServer, чтобы включить демо-режим."
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
            HStack(spacing: 8) {
                if let quality = result.quality {
                    badge(quality, color: .blue)
                }
                if let source = result.source {
                    badge(source, color: .gray)
                }
                if let audio = result.audioLabel {
                    badge(audio, color: .orange)
                }
            }
            HStack(spacing: 12) {
                Label(ByteCountFormatter.string(fromByteCount: result.sizeBytes, countStyle: .file),
                      systemImage: "internaldrive")
                Label("\(result.seeds)", systemImage: "arrow.down.circle")
                Spacer()
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.orange)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.2)))
            .foregroundStyle(color)
    }
}