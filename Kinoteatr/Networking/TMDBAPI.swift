import Foundation

enum TMDBError: LocalizedError {
    case noAPIKey
    case badResponse
    case invalidURL
    case network
    case invalidKey

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Не указан TMDB API ключ. Добавьте его в настройках."
        case .badResponse: return "Некорректный ответ от TMDB."
        case .invalidURL: return "Некорректный URL запроса."
        case .network: return "Не удалось подключиться к серверу TMDB. Проверьте интернет или включите VPN."
        case .invalidKey: return "TMDB отклонил API-ключ (401). Проверьте ключ в настройках."
        }
    }
}

enum DiscoverSort: String, CaseIterable, Identifiable {
    case popularityDesc = "popularity.desc"
    case voteAverageDesc = "vote_average.desc"
    case voteCountDesc = "vote_count.desc"
    case releaseDateDesc = "release_date.desc"
    case revenueDesc = "revenue.desc"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .popularityDesc: return "Популярность"
        case .voteAverageDesc: return "Рейтинг"
        case .voteCountDesc: return "Кол-во голосов"
        case .releaseDateDesc: return "Дата выхода"
        case .revenueDesc: return "Сборы"
        }
    }
}

actor TMDBAPI {
    static let shared = TMDBAPI()

    private let hosts = [
        URL(string: "https://api.themoviedb.org/3")!,
        URL(string: "https://api.tmdb.org/3")!,
    ]
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func request(host: URL, path: String, items: [URLQueryItem]) throws -> URLRequest {
        let key = AppSettings.shared.apiKey
        guard !key.isEmpty else { throw TMDBError.noAPIKey }

        var comps = URLComponents(url: host.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        let lang = Locale.current.identifier.hasPrefix("ru") ? "ru-RU" : "en-US"
        var query = items
        query.removeAll { ["api_key", "language"].contains($0.name) }
        query.append(URLQueryItem(name: "api_key", value: key))
        query.append(URLQueryItem(name: "language", value: lang))
        comps?.queryItems = query

        guard let url = comps?.url else { throw TMDBError.invalidURL }
        return URLRequest(url: url)
    }

    private func fetchData<T>(path: String, items: [URLQueryItem], decode: (Data) throws -> T) async throws -> T {
        for host in hosts {
            do {
                let (data, response) = try await URLSession.shared.data(for: try request(host: host, path: path, items: items))
                guard let http = response as? HTTPURLResponse else { throw TMDBError.badResponse }
                guard (200..<300).contains(http.statusCode) else {
                    throw http.statusCode == 401 ? TMDBError.invalidKey : TMDBError.badResponse
                }
                return try decode(data)
            } catch let error as URLError {
                if host == hosts.last { throw TMDBError.network }
                continue
            }
        }
        throw TMDBError.network
    }

    private func fetchPage(path: String, items: [URLQueryItem]) async throws -> Page<Movie> {
        try await fetchData(path: path, items: items) { try decoder.decode(Page<Movie>.self, from: $0) }
    }

    func discoverMovies(page: Int = 1, sort: DiscoverSort, genreID: Int?, year: Int?, minRating: Double) async throws -> Page<Movie> {
        var items = [URLQueryItem(name: "sort_by", value: sort.rawValue),
                     URLQueryItem(name: "page", value: String(page)),
                     URLQueryItem(name: "include_adult", value: "false"),
                     URLQueryItem(name: "include_video", value: "false")]
        if minRating > 0 {
            items.append(URLQueryItem(name: "vote_average.gte", value: String(minRating)))
            items.append(URLQueryItem(name: "vote_count.gte", value: "100"))
        }
        if let genreID { items.append(URLQueryItem(name: "with_genres", value: String(genreID))) }
        if let year {
            items.append(URLQueryItem(name: "primary_release_year", value: String(year)))
        }
        return try await fetchPage(path: "discover/movie", items: items)
    }

    func popularMovies(page: Int = 1) async throws -> Page<Movie> {
        try await fetchPage(path: "movie/popular", items: [URLQueryItem(name: "page", value: String(page))])
    }

    func fetchGenres() async throws -> [Genre] {
        struct Wrapper: Codable { let genres: [Genre] }
        return try await fetchData(path: "genre/movie/list", items: []) { try decoder.decode(Wrapper.self, from: $0).genres }
    }

    func searchMovies(query: String, page: Int = 1) async throws -> Page<Movie> {
        try await fetchPage(path: "search/movie", items: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
        ])
    }
}
