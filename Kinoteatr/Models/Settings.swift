import Foundation
import SwiftUI

enum AppTheme: String, Codable, Identifiable, CaseIterable {
    case dark, light, system

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    var label: String {
        switch self {
        case .dark: return "Тёмная"
        case .light: return "Светлая"
        case .system: return "Системная"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("tmdb_api_key") var apiKey: String = "30ca2adcda3a3d78ecdf2e12f5117231"
    @AppStorage("jackett_url") var jackettURL: String = ""
    @AppStorage("torrserver_url") var torrServerURL: String = ""
    @AppStorage("torrserver_password") var torrServerPassword: String = ""
    @AppStorage("tmdb_proxy_url") var tmdbProxyURL: String = ""
    @AppStorage("remote_config_url") var remoteConfigURL: String = "http://192.168.0.150:8088/config"
    @AppStorage("app_theme") private(set) var themeRaw: String = AppTheme.dark.rawValue
    @AppStorage("default_quality") var defaultQuality: String = "Авто"
    @AppStorage("download_folder") var downloadFolder: String = "Kinoteatr"
    @AppStorage("prefer_russian_audio") var preferRussianAudio: Bool = true
    @AppStorage("developer_mode") var developerMode: Bool = false
    @AppStorage("developer_code") var developerCode: String = ""

    var theme: AppTheme {
        AppTheme(rawValue: themeRaw) ?? .dark
    }

    func setTheme(_ t: AppTheme) {
        themeRaw = t.rawValue
        objectWillChange.send()
    }
}

struct CacheSettings: Codable {
    var posterBase: URL
    var genresCache: [Genre]?
    var lastSaved: Date

    static var posterBase: URL {
        let trimmed = AppSettings.shared.tmdbProxyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let proxy = URL(string: trimmed) {
            return proxy.appendingPathComponent("t/p/w342")
        }
        return URL(string: "https://image.tmdb.org/t/p/w342")!
    }

    static let path: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }()

    static func read() -> CacheSettings {
        guard let data = try? Data(contentsOf: path),
              let decoded = try? JSONDecoder().decode(CacheSettings.self, from: data)
        else {
            return CacheSettings(posterBase: CacheSettings.posterBase, genresCache: nil, lastSaved: .distantPast)
        }
        return decoded
    }

    mutating func save() {
        lastSaved = .now
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: Self.path)
        }
    }
}
