import Foundation
import SwiftUI

struct Genre: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
}

final class GenreCatalog: ObservableObject {
    static let shared = GenreCatalog()

    @Published private(set) var genres: [Genre] = []

    func name(for id: Int) -> String? {
        genres.first { $0.id == id }?.name
    }

    func load() async {
        let cfg = CacheSettings.read()
        if let cached = cfg.genresCache, !cached.isEmpty {
            load(genres: cached)
            return
        }
        await refresh()
    }

    func refresh() async {
        do {
            let list = try await TMDBAPI.shared.fetchGenres()
            load(genres: list)
        } catch {
            loadFallback()
        }
    }

    private func load(genres: [Genre]) {
        DispatchQueue.main.async {
            self.genres = genres
        }
        var cfg = CacheSettings.read()
        cfg.genresCache = genres
        cfg.save()
    }

    private func loadFallback() {
        let fallback: [Genre] = [
            Genre(id: 28, name: "Action"),
            Genre(id: 35, name: "Comedy"),
            Genre(id: 18, name: "Drama"),
            Genre(id: 27, name: "Horror"),
            Genre(id: 878, name: "Science Fiction"),
            Genre(id: 16, name: "Animation"),
            Genre(id: 12, name: "Adventure"),
            Genre(id: 14, name: "Fantasy"),
            Genre(id: 53, name: "Thriller"),
            Genre(id: 80, name: "Crime"),
            Genre(id: 10749, name: "Romance"),
            Genre(id: 9648, name: "Mystery"),
            Genre(id: 36, name: "History"),
            Genre(id: 10751, name: "Family"),
            Genre(id: 10752, name: "War"),
            Genre(id: 37, name: "Western"),
            Genre(id: 10402, name: "Music"),
            Genre(id: 99, name: "Documentary"),
        ]
        load(genres: fallback)
    }
}
