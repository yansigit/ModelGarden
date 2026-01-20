import Foundation
import Observation
import MLXLMCommon
import UniformTypeIdentifiers

@Observable
@MainActor
public final class ChatViewModel {
    private let service: MLXService
    public init(service: MLXService) { self.service = service }

    public var prompt: String = ""
    public var messages: [Message] = [.system("You are a helpful assistant!")]
    public var selectedModel: LMModel = MLXService.availableModels.first!
    public var mediaSelection = MediaSelection()
    public var isGenerating = false
    private var generateTask: Task<Void, any Error>?
    private var generateCompletionInfo: GenerateCompletionInfo?
    public var tokensPerSecond: Double { generateCompletionInfo?.tokensPerSecond ?? 0 }
    public var modelDownloadProgress: Progress? { service.modelDownloadProgress }
    public var errorMessage: String?

    public func generate() async {
        if let existingTask = generateTask { existingTask.cancel(); generateTask = nil }
        isGenerating = true
        messages.append(.user(prompt, images: mediaSelection.images, videos: mediaSelection.videos))
        messages.append(.assistant(""))
        clear(.prompt)

        generateTask = Task {
            for await generation in try await service.generate(messages: messages, model: selectedModel) {
                switch generation {
                case .chunk(let chunk):
                    if let last = messages.last { last.content += chunk }
                case .info(let info):
                    generateCompletionInfo = info
                case .toolCall:
                    break
                }
            }
        }
        do {
            try await withTaskCancellationHandler {
                try await generateTask?.value
            } onCancel: {
                Task { @MainActor in
                    self.generateTask?.cancel()
                    if let last = self.messages.last { last.content += "\n[Cancelled]" }
                }
            }
        } catch {
            // Log error to console and show to user
            print("❌ ChatViewModel: Error during generation")
            print("   Model: \(selectedModel.name)")
            print("   Error: \(error)")
            print("   Localized: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isGenerating = false
        generateTask = nil
    }

    public func addMedia(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            if let mediaType = UTType(filenameExtension: url.pathExtension) {
                if mediaType.conforms(to: .image) { mediaSelection.images = [url] }
                else if mediaType.conforms(to: .movie) { mediaSelection.videos = [url] }
            }
        } catch { errorMessage = "Failed to load media item.\n\nError: \(error)" }
    }

    public func clear(_ options: ClearOption) {
        if options.contains(.prompt) { prompt = ""; mediaSelection = .init() }
        if options.contains(.chat) { messages = []; generateTask?.cancel() }
        if options.contains(.meta) { generateCompletionInfo = nil }
        errorMessage = nil
    }
}

@Observable
public final class MediaSelection: @unchecked Sendable {
    public var isShowing = false
    public var images: [URL] = [] { didSet { didSetURLs(oldValue, images) } }
    public var videos: [URL] = [] { didSet { didSetURLs(oldValue, videos) } }
    public var isEmpty: Bool { images.isEmpty && videos.isEmpty }
    private func didSetURLs(_ old: [URL], _ new: [URL]) {
        new.filter { !old.contains($0) }.forEach { _ = $0.startAccessingSecurityScopedResource() }
        old.filter { !new.contains($0) }.forEach { $0.stopAccessingSecurityScopedResource() }
    }
}

public struct ClearOption: RawRepresentable, OptionSet, Sendable { public let rawValue: Int; public init(rawValue: Int){self.rawValue=rawValue}
    public static let prompt = ClearOption(rawValue: 1<<0)
    public static let chat = ClearOption(rawValue: 1<<1)
    public static let meta = ClearOption(rawValue: 1<<2)
}
