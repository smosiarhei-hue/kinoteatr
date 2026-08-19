import SwiftUI

struct MovieCardView: View {
    let movie: Movie
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 8) {
                poster
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Label(movie.releaseYear, systemImage: "calendar")
                        Spacer()
                        Label("\(String(format: "%.1f", movie.voteAverage))", systemImage: "star.fill")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var poster: some View {
        AsyncImage(url: movie.posterURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                Color(.tertiarySystemFill)
                    .overlay(Image(systemName: "film").font(.largeTitle).foregroundStyle(.secondary))
            default:
                Color(.tertiarySystemFill)
                    .overlay(ProgressView())
            }
        }
        .aspectRatio(2/3, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            votesBadge
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 4)
                .padding(8)
        }
    }

    private var votesBadge: some View {
        Text(movie.votesText)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.6), in: Capsule())
            .foregroundStyle(.white)
            .padding(6)
    }
}
