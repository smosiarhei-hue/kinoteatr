import SwiftUI

@main
struct KinoteatrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var player = TorrentPlayerService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(settings)
                .environmentObject(player)
                .preferredColorScheme(settings.theme.colorScheme)
                .task {
                    RemoteConfigService.shared.start()
                    await RemoteConfigService.shared.sync()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await RemoteConfigService.shared.sync() }
                    }
                }
        }
    }
}

