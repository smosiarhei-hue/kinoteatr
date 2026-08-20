import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var versionTaps = 0
    @State private var showDeveloperHint = false

    var body: some View {
        NavigationStack {
            Form {
                playbackSection
                appearanceSection
                if settings.developerMode {
                    developerSection
                }
                aboutSection
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var playbackSection: some View {
        Section("Воспроизведение") {
            Toggle("Предпочитать русскую озвучку", isOn: $settings.preferRussianAudio)
            Text("Раздачи с дубляжом или русской дорожкой идут первыми.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Качество по умолчанию", selection: $settings.defaultQuality) {
                ForEach(["480p", "720p", "1080p", "4K"], id: \.self) { q in
                    Text(q).tag(q)
                }
            }
        }
    }

    private var appearanceSection: some View {
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

    private var developerSection: some View {
        Section {
            SecureField("API key v3 или Read Access Token v4", text: $settings.apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)
            Text("TMDB. Поддерживаются v3 API key и v4 Read Access Token.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("http://192.168.1.10:9117/api/v2.0/indexers/all/results?apikey=…", text: $settings.jackettURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Text("Jackett. Без него работает демо-провайдер magnet-ссылок.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Выключить режим разработчика", role: .destructive) {
                settings.developerMode = false
                versionTaps = 0
            }
        } header: {
            Label("Режим разработчика", systemImage: "wrench.and.screwdriver")
        }
    }

    private var aboutSection: some View {
        Section("О приложении") {
            HStack {
                Text("Версия")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                versionTaps += 1
                if versionTaps >= 7 && !settings.developerMode {
                    settings.developerMode = true
                    showDeveloperHint = true
                }
            }
        }
        .alert("Режим разработчика включён", isPresented: $showDeveloperHint) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text("Появились настройки TMDB и Jackett.")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
