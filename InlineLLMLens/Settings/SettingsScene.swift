import SwiftUI

struct SettingsScene: Scene {
    var body: some Scene {
        Settings {
            SettingsRoot()
                .frame(minWidth: 560, minHeight: 420)
        }
    }
}

private struct SettingsRoot: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            ModelsSettingsView()
                .tabItem { Label("Models", systemImage: "cpu") }
            CaptureSettingsView()
                .tabItem { Label("Capture", systemImage: "text.cursor") }
            ResponseSettingsView()
                .tabItem { Label("Response", systemImage: "text.bubble") }
            PermissionsView()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .padding(20)
    }
}
