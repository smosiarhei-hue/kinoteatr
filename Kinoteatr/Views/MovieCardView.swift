import SwiftUI

struct MovieCardView: View {
    let movie: Movie
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 7) {
                poster
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: 34, alignment: .topLeading)

                    HStack(spacing: 6) {
                        Text(movie.releaseYear)
                        Spacer(minLength: 4)
                        Label(String(format: "%.1f", movie.voteAverage), systemImage: "star.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.orange)
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Фильм \(movie.title), рейтинг \(String(format: "%.1f", movie.voteAverage))")
        .accessibilityHint("Открыть варианты просмотра")
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
        .aspectRatio(2/3, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topTrailing) { votesBadge }
        .overlay(alignment: .bottomTrailing) { playBadge }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.22), lineWidth: 0.5)
        )
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(.tertiarySystemFill))
            .overlay {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }

    private var playBadge: some View {
        ZStack {
            Circle().fill(.black.opacity(0.58))
            Image(systemName: "play.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 1)
        }
        .frame(width: 28, height: 28)
        .padding(7)
    }

    private var votesBadge: some View {
        Text(movie.votesText)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.62), in: Capsule())
            .foregroundStyle(.white)
            .padding(6)
    }
}
