import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var didReload = false

    var body: some View {
        NavigationStack {
            Form {
                Section("TMDB (каталог фильмов)") {
                    TextField("API ключ v3", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Бесплатный ключ на themoviedb.org → Settings → API")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Торренты (Jackett, опционально)") {
                    TextField("http://192.168.1.10:9117/api/v2.0/indexers/all/results?apikey=…", text: $settings.jackettURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Text("Без Jackett работает демо-провайдер magnet-ссылок.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Предпочитать русскую озвучку", isOn: $settings.preferRussianAudio)
                    Text("Раздачи с дубляжом/русской дорожкой идут первыми.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Оформление") {
                    Picker("Тема", selection: Binding(
                        get: { settings.themeRaw },
                        set: { settings.setTheme(AppTheme(rawValue: $0) ?? .dark) }
                    )) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.label).tag(theme.rawValue)
                        }
                    }
                }
            }
            .navigationTitle("Настройки")
        }
    }
}
