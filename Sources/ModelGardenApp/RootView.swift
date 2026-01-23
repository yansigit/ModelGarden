import SwiftUI
import ModelGardenKit

struct RootView: View {
    @Environment(ThemeSettings.self) private var theme
    @Environment(ModelSettings.self) private var modelSettings
    @State private var tab: Tab = .chat
    let service: MLXService

    enum Tab: Hashable { case chat, models, settings }

    var body: some View {
        TabView(selection: $tab) {
            ChatScreen(service: service, modelSettings: modelSettings)
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(Tab.chat)
            ModelManagerScreen()
                .tabItem { Label("Models", systemImage: "square.stack.3d.up.fill") }
                .tag(Tab.models)
            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "paintpalette.fill") }
                .tag(Tab.settings)
        }
        .tint(theme.accentColor)
        .preferredColorScheme(theme.colorScheme)
    }
}
