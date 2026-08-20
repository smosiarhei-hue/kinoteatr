import SwiftUI

struct MovieDetailView: View {
    let movie: Movie
    var onWatch: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    infoRow
                    if !movie.genreNames.isEmpty {
                        genreChips
                    }
                    overviewSection
                    watchButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle(movie.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            poster
            VStack(alignment: .leading, spacing: 8) {
                Text(movie.title)
                    .font(.title3.weight(.bold))
                    .lineLimit(3)
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.orange)
                    Text(String(format: "%.1f", movie.voteAverage))
                        .font(.headline)
                    Text("(\(movie.votesText))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(movie.releaseYear)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var poster: some View {
        AsyncImage(url: movie.posterURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                placeholder
            default:
                placeholder.overlay(ProgressView().tint(.orange))
            }
        }
        .frame(width: 110, height: 165)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(.tertiarySystemFill))
            .overlay {
                Image(systemName: "film")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
    }

    private var infoRow: some View {
        HStack(spacing: 16) {
            infoItem(icon: "star.fill", label: "Рейтинг", value: String(format: "%.1f", movie.voteAverage))
            infoItem(icon: "person.2", label: "Голосов", value: movie.votesText)
            infoItem(icon: "calendar", label: "Год", value: movie.releaseYear)
        }
    }

    private func infoItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var genreChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Жанры")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(movie.genreNames, id: \.self) { name in
                        Text(name)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.orange.opacity(0.16)))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Описание")
                .font(.headline)
            Text(movie.overview.isEmpty ? "Описание отсутствует." : movie.overview)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineSpacing(3)
        }
    }

    private var watchButton: some View {
        Button(action: onWatch) {
            HStack {
                Image(systemName: "play.fill")
                Text("Смотреть")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
    }
}
