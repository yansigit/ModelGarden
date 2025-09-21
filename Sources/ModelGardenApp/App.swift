import SwiftUI
import ModelGardenKit

@main
struct ModelGardenMainApp: App {
    @State private var theme = ThemeSettings()
    private let service = MLXService()

    var body: some Scene {
        WindowGroup {
            RootView(service: service)
                .environment(theme)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        // Note: When opening this package in Xcode, assign
        // Sources/ModelGardenApp/ModelGardenApp.entitlements to the app target (Signing & Capabilities)
        // to enable the increased memory limit and sandbox permissions.
        #endif
    }
}
