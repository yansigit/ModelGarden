import SwiftUI
import Observation

@Observable public final class ThemeSettings {
    public enum Scheme: String, CaseIterable, Identifiable { case system, light, dark; public var id: String { rawValue } }
    public var scheme: Scheme = .system
    public var accentColor: Color = .accentColor
    public var colorScheme: ColorScheme? { switch scheme { case .system: nil; case .light: .light; case .dark: .dark } }
    public init() {}
}

struct SettingsScreen: View {
    @Environment(ThemeSettings.self) private var theme
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: .init(get: { theme.scheme }, set: { theme.scheme = $0 })) {
                    ForEach(ThemeSettings.Scheme.allCases) { s in Text(s.rawValue.capitalized).tag(s) }
                }
                ColorPicker("Accent Color", selection: .init(get: { theme.accentColor }, set: { theme.accentColor = $0 }))
            }
            Section("About") {
                LabeledContent("App") { Text("ModelGarden") }
                LabeledContent("Version") { Text("0.1.0") }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
