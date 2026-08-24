import Foundation

struct Movie: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let voteCount: Int
    let popularity: Double
    let releaseDate: String?
    let genreIds: [Int]?
    let originalLanguage: String
    let originalTitle: String?

    enum CodingKeys: String, CodingKey {
        case id, title, overview, popularity
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case releaseDate = "release_date"
        case genreIds = "genre_ids"
        case originalLanguage = "original_language"
        case originalTitle = "original_title"
    }

    var releaseYear: String {
        guard let releaseDate, releaseDate.count >= 4 else { return "—" }
        return String(releaseDate.prefix(4))
    }

    var posterURL: URL? {
        posterPath.flatMap {
            CacheSettings.posterBase.appendingPathComponent($0)
        }
    }

    var backdropURL: URL? {
        let base = URL(string: "https://image.tmdb.org/t/p/w780")!
        return backdropPath.flatMap { base.appendingPathComponent($0) }
    }

    var genreNames: [String] {
        (genreIds ?? []).compactMap { GenreCatalog.shared.name(for: $0) }
    }

    var votesText: String {
        if voteCount >= 1000 {
            return "\(String(format: "%.1fK", Double(voteCount) / 1000))"
        }
        return "\(voteCount)"
    }
}

struct Page<T: Codable & Identifiable & Hashable>: Codable {
    let page: Int
    let results: [T]
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
    }
}
