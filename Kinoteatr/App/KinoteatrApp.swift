import SwiftUI

@main
struct KinoteatrApp: App {
    @StateObject private var settings = AppSettings()
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
