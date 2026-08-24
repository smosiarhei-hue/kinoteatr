import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var showDevLogin = false
    @State private var codeInput = ""
    @State private var loginError = false

    var body: some View {
        NavigationStack {
            Form {
                playbackSection
                appearanceSection
                developerSection
                aboutSection
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDevLogin) { devLoginSheet }
        }
    }

    private var playbackSection: some View {
        Section("Воспроизведение") {
            Toggle("Предпочитать русскую озвучку", isOn: $settings.preferRussianAudio)
            Text("Раздачи с дубляжом или русской дорожкой идут первыми.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Качество по умолчанию", selection: $settings.defaultQuality) {
                ForEach(["Авто", "480p", "720p", "1080p", "4K"], id: \.self) { q in
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

    @ViewBuilder
    private var developerSection: some View {
        if settings.developerMode {
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

                TextField("http://192.168.1.10:8090", text: $settings.torrServerURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("Пароль TorrServer (если задан)", text: $settings.torrServerPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.password)
                Text("Пароль TorrServer, если он задан на сервере.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("http://192.168.0.150:8088 (если TMDB заблокирован без VPN)", text: $settings.tmdbProxyURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Text("Прокси TMDB на ПК: каталог и постеры идут через него, VPN не нужен. Пусто = напрямую с api.themoviedb.org.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("TorrServer на ПК — реальный стриминг торрентов. Без него проигрывается демо-ролик.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Выйти из режима разработчика", role: .destructive) {
                    settings.developerMode = false
                }
            } header: {
                Label("Режим разработчика", systemImage: "wrench.and.screwdriver")
            }
        } else {
            Section {
                Button {
                    showDevLogin = true
                } label: {
                    Label("Режим разработчика", systemImage: "lock")
                }
            } footer: {
                Text("Доступ по коду разработчика.")
            }
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
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

extension SettingsView {
    private var devLoginSheet: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(settings.developerCode.isEmpty ? "Задайте код разработчика" : "Введите код разработчика", text: $codeInput)
                        .keyboardType(.numberPad)
                } footer: {
                    Text(settings.developerCode.isEmpty
                         ? "Первый вход: придумайте и введите свой код. Он сохранится на этом устройстве."
                         : "Введите код, который вы задали ранее.")
                }
            }
            .navigationTitle("Режим разработчика")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        showDevLogin = false
                        codeInput = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Войти") { attemptLogin() }
                        .disabled(codeInput.isEmpty)
                }
            }
            .alert("Неверный код", isPresented: $loginError) {
                Button("ОК", role: .cancel) {}
            }
        }
        .presentationDetents([.medium])
    }

    private func attemptLogin() {
        if settings.developerCode.isEmpty {
            settings.developerCode = codeInput
            settings.developerMode = true
            showDevLogin = false
            codeInput = ""
        } else if codeInput == settings.developerCode {
            settings.developerMode = true
            showDevLogin = false
            codeInput = ""
        } else {
            loginError = true
            codeInput = ""
        }
    }
}
