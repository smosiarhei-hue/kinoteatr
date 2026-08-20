import SwiftUI

@main
struct KinoteatrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var player = TorrentPlayerService()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(settings)
                .environmentObject(player)
                .preferredColorScheme(settings.theme.colorScheme)
        }
    }
}

