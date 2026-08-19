import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Фильмы", systemImage: "movieclapper") }
                .tag(0)
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
                .tag(1)
        }
        .tint(.orange)
    }
}
