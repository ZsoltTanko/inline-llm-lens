import SwiftUI

@main
struct InlineLLMLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        SettingsScene()
    }
}
