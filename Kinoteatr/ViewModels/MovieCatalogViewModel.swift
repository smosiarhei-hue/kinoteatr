import Foundation

@MainActor
final class MovieCatalogViewModel: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var sort: DiscoverSort = .popularityDesc
    @Published var selectedGenre: Genre?
    @Published var year: Int?
    @Published var minRating: Double = 0

    @Published var searchQuery = ""
    @Published var useSearch = false

    private(set) var currentPage = 1
    private(set) var totalPages = 1
    var hasMore: Bool { currentPage < totalPages }

    var genres: [Genre] { genreCatalog.genres }
    private let genreCatalog = GenreCatalog.shared

    var years: [Int] {
        let current = Calendar.current.component(.year, from: .now)
        return Array((1950...current).reversed())
    }

    func loadFirst() async {
        await genreCatalog.load()
        currentPage = 1
        movies = []
        await load(page: 1, replace: true)
    }

    func loadMoreIfNeeded(current movie: Movie) async {
        guard hasMore, !isLoading else { return }
        guard let index = movies.firstIndex(of: movie), index >= movies.count - 8 else { return }
        await load(page: currentPage + 1, replace: false)
    }

    func applyFilters() async {
        useSearch = false
        await loadFirst()
    }

    func runSearch() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        useSearch = true
        currentPage = 1
        movies = []
        totalPages = 1
        await loadSearch(page: 1)
    }

    func clearSearch() async {
        searchQuery = ""
        if useSearch {
            useSearch = false
            await loadFirst()
        }
    }

    func resetFilters() async {
        sort = .popularityDesc
        selectedGenre = nil
        year = nil
        minRating = 0
        await loadFirst()
    }

    private func load(page: Int, replace: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await TMDBAPI.shared.discoverMovies(
                page: page,
                sort: sort,
                genreID: selectedGenre?.id,
                year: year,
                minRating: minRating
            )
            append(result, page: page, replace: replace)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadSearch(page: Int) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await TMDBAPI.shared.searchMovies(query: searchQuery, page: page)
            addMovies(result, page: page)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func append(_ result: Page<Movie>, page: Int, replace: Bool) {
        addMovies(result, page: page, replaceAll: replace)
    }

    private func addMovies(_ result: Page<Movie>, page: Int, replaceAll: Bool = false) {
        totalPages = max(result.totalPages, 1)
        currentPage = page
        if replaceAll || movies.isEmpty {
            movies = result.results
        } else {
            let existing = Set(movies.map(\.id))
            movies.append(contentsOf: result.results.filter { !existing.contains($0.id) })
        }
    }
}
