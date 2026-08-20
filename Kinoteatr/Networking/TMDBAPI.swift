import Foundation

enum TMDBError: LocalizedError {
    case noAPIKey
    case badResponse(Int)
    case invalidURL
    case network(URLError)
    case invalidKey
    case decoding

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Не указан TMDB API ключ. Добавьте его в настройках."
        case .badResponse(let statusCode):
            return "TMDB вернул ошибку сервера (код \(statusCode)). Попробуйте повторить запрос позже."
        case .invalidURL:
            return "Некорректный URL запроса к TMDB."
        case .network(let error):
            return TMDBError.networkMessage(for: error)
        case .invalidKey:
            return "TMDB отклонил API-ключ. Проверьте, что в настройках вставлен v3 API key или v4 Read Access Token."
        case .decoding:
            return "TMDB ответил в неожиданном формате. Обновите каталог ещё раз."
        }
    }

    private static func networkMessage(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "Нет соединения с интернетом. Проверьте Wi‑Fi/мобильную сеть и повторите запрос."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Не удалось подключиться к TMDB. Если вы запускаете через GBox, попробуйте включить VPN или другую сеть."
        case .timedOut:
            return "TMDB не ответил вовремя. Проверьте интернет или попробуйте ещё раз."
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot:
            return "iOS не смогла установить защищённое соединение с TMDB. Проверьте дату/время устройства и сеть."
        default:
            return "Не удалось подключиться к серверу TMDB. Проверьте интернет или включите VPN."
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

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func request(host: URL, path: String, items: [URLQueryItem]) throws -> URLRequest {
        let key = AppSettings.shared.apiKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "Bearer ", with: "", options: [.caseInsensitive, .anchored])
        guard !key.isEmpty else { throw TMDBError.noAPIKey }

        var url = host
        for component in path.split(separator: "/") {
            url.appendPathComponent(String(component))
        }

        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let lang = Locale.current.identifier.hasPrefix("ru") ? "ru-RU" : "en-US"
        var query = items
        query.removeAll { ["api_key", "language"].contains($0.name) }
        query.append(URLQueryItem(name: "language", value: lang))

        var request: URLRequest
        if isV4ReadAccessToken(key) {
            comps?.queryItems = query
            guard let url = comps?.url else { throw TMDBError.invalidURL }
            request = URLRequest(url: url)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        } else {
            query.append(URLQueryItem(name: "api_key", value: key))
            comps?.queryItems = query
            guard let url = comps?.url else { throw TMDBError.invalidURL }
            request = URLRequest(url: url)
        }

        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Kinoteatr/1.0", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func isV4ReadAccessToken(_ key: String) -> Bool {
        key.hasPrefix("eyJ") || key.split(separator: ".").count == 3
    }

    private func fetchData<T>(path: String, items: [URLQueryItem], decode: (Data) throws -> T) async throws -> T {
        var lastNetworkError: URLError?

        for (index, host) in hosts.enumerated() {
            do {
                let (data, response) = try await session.data(for: try request(host: host, path: path, items: items))
                guard let http = response as? HTTPURLResponse else { throw TMDBError.badResponse(0) }
                guard (200..<300).contains(http.statusCode) else {
                    throw http.statusCode == 401 ? TMDBError.invalidKey : TMDBError.badResponse(http.statusCode)
                }

                do {
                    return try decode(data)
                } catch {
                    throw TMDBError.decoding
                }
            } catch let error as TMDBError {
                throw error
            } catch let error as URLError {
                lastNetworkError = error
                if index == hosts.count - 1 {
                    throw TMDBError.network(error)
                }
                continue
            }
        }

        throw TMDBError.network(lastNetworkError ?? URLError(.cannotConnectToHost))
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

