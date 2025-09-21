import SwiftUI

struct GradientBackground: View {
    var body: some View {
        LinearGradient(colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

struct AsyncButton<LabelView: View>: View {
    var action: () async -> Void
    @ViewBuilder var label: () -> LabelView
    @State private var isRunning = false
    var body: some View {
        Button {
            guard !isRunning else { return }
            isRunning = true
            Task { await action(); isRunning = false }
        } label: { ZStack { if isRunning { ProgressView() } else { label() } } }
    }
}
