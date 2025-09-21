import SwiftUI
import Observation
import ModelGardenKit

struct ChatScreen: View {
    @State private var vm: ChatViewModel
    init(service: MLXService) { _vm = State(initialValue: ChatViewModel(service: service)) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ConversationView(messages: vm.messages)
                Divider()
                if !vm.mediaSelection.isEmpty { MediaPreviewsView(mediaSelection: vm.mediaSelection) }
                let mediaAction: (() -> Void)? = {
                    #if os(macOS)
                    return vm.selectedModel.isVisionModel ? { vm.mediaSelection.isShowing = true } : nil
                    #else
                    return nil
                    #endif
                }()
                PromptField(prompt: $vm.prompt, sendButtonAction: vm.generate, mediaButtonAction: mediaAction)
                    .padding()
            }
            .background(GradientBackground())
            .navigationTitle("ModelGarden Chat")
            .toolbar { ChatToolbarView(vm: vm) }
            .safeAreaInset(edge: .bottom) {
                if vm.isGenerating { TypingIndicatorView().padding(.horizontal) }
            }
            #if os(macOS)
            .fileImporter(isPresented: $vm.mediaSelection.isShowing, allowedContentTypes: [.image, .movie], onCompletion: vm.addMedia)
            #endif
        }
    }
}

// MARK: UI components for Chat

struct ConversationView: View {
    var messages: [Message]
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }
}

struct MessageBubble: View {
    @Bindable var message: Message
    var body: some View {
        HStack(alignment: .bottom) {
            if message.role != .user { avatar }
            bubble
            if message.role == .user { avatar }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .padding(.horizontal, 4)
    }
    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.content)
                .font(.body)
                .textSelection(.enabled)
            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(message.role == .user ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
        )
    }
    private var avatar: some View {
        ZStack {
            Circle().fill(message.role == .user ? .blue : (message.role == .assistant ? .green : .orange))
            Image(systemName: message.role == .user ? "person.fill" : (message.role == .assistant ? "sparkles" : "gear"))
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .frame(width: 24, height: 24)
        .padding(4)
    }
}

struct MediaPreviewsView: View {
    @Bindable var mediaSelection: MediaSelection
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(mediaSelection.images, id: \.self) { url in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.1))
                        .frame(width: 120, height: 80)
                        .overlay(Image(systemName: "photo").font(.largeTitle))
                        .overlay(Text(url.lastPathComponent).font(.caption2).lineLimit(1).padding(4), alignment: .bottom)
                }
                ForEach(mediaSelection.videos, id: \.self) { url in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.1))
                        .frame(width: 120, height: 80)
                        .overlay(Image(systemName: "video").font(.largeTitle))
                        .overlay(Text(url.lastPathComponent).font(.caption2).lineLimit(1).padding(4), alignment: .bottom)
                }
            }.padding(.horizontal)
        }.padding(.vertical, 8)
    }
}

struct PromptField: View {
    @Binding var prompt: String
    var sendButtonAction: () async -> Void
    var mediaButtonAction: (() -> Void)?
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if let mediaButtonAction { Button(action: mediaButtonAction) { Image(systemName: "paperclip") }.help("Attach image/video") }
            TextEditor(text: $prompt)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 44, maxHeight: 140)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(.thinMaterial))
            AsyncButton(action: sendButtonAction) { Label("Send", systemImage: "arrow.up.circle.fill") }
                .buttonStyle(.borderedProminent)
        }
    }
}

struct ChatToolbarView: ToolbarContent {
    @Bindable var vm: ChatViewModel
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Picker("Model", selection: $vm.selectedModel) {
                ForEach(MLXService.availableModels, id: \.self) { model in
                    Text(model.displayName).tag(model)
                }
            }.pickerStyle(.menu)
        }
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 12) {
                if vm.tokensPerSecond > 0 {
                    Label(String(format: "%.1f tok/s", vm.tokensPerSecond), systemImage: "speedometer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if vm.isGenerating { ProgressView() }
            }
        }
    }
}

struct TypingIndicatorView: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(opacity(for: i))
            }
            Text("Generating…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
        .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { phase = 1 } }
    }
    private func opacity(for index: Int) -> Double { Double(0.4 + 0.6 * sin(phase * .pi + Double(index) * 0.8).magnitude) }
}
