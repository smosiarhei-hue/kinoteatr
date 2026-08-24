import Foundation

struct RemoteConfig: Codable {
    var jackettURL: String?
    var torrServerURL: String?
    var torrServerPassword: String?
    var tmdbProxyURL: String?
    var defaultQuality: String?
    var preferRussianAudio: Bool?
}

@MainActor
final class RemoteConfigService: ObservableObject {
    static let shared = RemoteConfigService()

    @Published var lastSyncText = "Ещё не синхронизировано"
    @Published var syncError: String?

    private var timer: Timer?

    private init() {}

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { await self?.sync() }
        }
    }

    func configURL() -> URL? {
        // Ручной адрес конфигурации (если задан) — в приоритете.
        let manual = AppSettings.shared.remoteConfigURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manual.isEmpty, let u = URL(string: manual) { return u }
        // Иначе выводим из адреса TorrServer: http://<хост>:8088/config
        let torr = AppSettings.shared.torrServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let t = URL(string: torr), let host = t.host else { return nil }
        var comps = URLComponents()
        comps.scheme = "http"
        comps.host = host
        comps.port = 8088
        comps.path = "/config"
        return comps.url
    }

    func sync() async {
        guard let url = configURL() else {
            syncError = "Нет адреса ПК. Задайте TorrServer в настройках или URL конфигурации."
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                syncError = "Конфигурация с ПК недоступна (HTTP \(code)). ПК включён? Прокси работает?"
                return
            }
            let config = try JSONDecoder().decode(RemoteConfig.self, from: data)
            apply(config)
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            lastSyncText = "Загружено с ПК в \(formatter.string(from: .now))"
            syncError = nil
        } catch {
            syncError = "Не удалось загрузить конфигурацию: \(error.localizedDescription)"
        }
    }

    private func apply(_ c: RemoteConfig) {
        if let v = c.jackettURL { AppSettings.shared.jackettURL = v }
        if let v = c.torrServerURL { AppSettings.shared.torrServerURL = v }
        if let v = c.torrServerPassword { AppSettings.shared.torrServerPassword = v }
        if let v = c.tmdbProxyURL { AppSettings.shared.tmdbProxyURL = v }
        if let v = c.defaultQuality { AppSettings.shared.defaultQuality = v }
        if let v = c.preferRussianAudio { AppSettings.shared.preferRussianAudio = v }
    }
}