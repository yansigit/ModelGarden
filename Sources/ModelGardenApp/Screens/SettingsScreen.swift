import SwiftUI
import Observation
import ModelGardenKit

@Observable public final class ThemeSettings {
    public enum Scheme: String, CaseIterable, Identifiable { case system, light, dark; public var id: String { rawValue } }
    public var scheme: Scheme = .system
    public var accentColor: Color = .accentColor
    public var colorScheme: ColorScheme? { switch scheme { case .system: nil; case .light: .light; case .dark: .dark } }
    public init() {}
}

struct SettingsScreen: View {
    @Environment(ThemeSettings.self) private var theme
    @Environment(ModelSettings.self) private var modelSettings
    
    var body: some View {
        @Bindable var modelSettings = modelSettings
        
        Form {
            Section("Appearance") {
                Picker("Theme", selection: .init(get: { theme.scheme }, set: { theme.scheme = $0 })) {
                    ForEach(ThemeSettings.Scheme.allCases) { s in Text(s.rawValue.capitalized).tag(s) }
                }
                ColorPicker("Accent Color", selection: .init(get: { theme.accentColor }, set: { theme.accentColor = $0 }))
            }
            
            Section {
                TextField("Custom EOS Tag", text: $modelSettings.customEOSTag)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            } header: {
                Text("Model")
            } footer: {
                Text("Custom End-of-Sequence token(s) to stop generation. Separate multiple tokens with commas. Examples: <|end|>, <|eot_id|>, </s>")
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
