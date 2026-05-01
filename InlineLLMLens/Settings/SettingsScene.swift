import SwiftUI

struct SettingsScene: Scene {
    var body: some Scene {
        Settings {
            SettingsRoot()
                .frame(minWidth: 720, minHeight: 520)
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
            PromptsSettingsView()
                .tabItem { Label("Prompts", systemImage: "text.quote") }
            CaptureSettingsView()
                .tabItem { Label("Capture", systemImage: "text.cursor") }
            PermissionsView()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .padding(20)
    }
}
