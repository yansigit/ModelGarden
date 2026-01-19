import Foundation
import Observation
import MLX
import MLXLLM
import MLXLMCommon
import MLXVLM

@Observable
@MainActor
public final class MLXService {
    public static let availableModels: [LMModel] = [
        LMModel(name: "llama3.2:1b", configuration: LLMRegistry.llama3_2_1B_4bit, type: .llm),
        LMModel(name: "qwen2.5:1.5b", configuration: LLMRegistry.qwen2_5_1_5b, type: .llm),
        LMModel(name: "smolLM:135m", configuration: LLMRegistry.smolLM_135M_4bit, type: .llm),
        LMModel(name: "qwen3:0.6b", configuration: LLMRegistry.qwen3_0_6b_4bit, type: .llm),
        LMModel(name: "qwen3:1.7b", configuration: LLMRegistry.qwen3_1_7b_4bit, type: .llm),
        LMModel(name: "qwen3:4b", configuration: LLMRegistry.qwen3_4b_4bit, type: .llm),
        LMModel(name: "qwen3:8b", configuration: LLMRegistry.qwen3_8b_4bit, type: .llm),
        LMModel(name: "qwen2.5VL:3b", configuration: VLMRegistry.qwen2_5VL3BInstruct4Bit, type: .vlm),
        LMModel(name: "qwen2VL:2b", configuration: VLMRegistry.qwen2VL2BInstruct4Bit, type: .vlm),
        LMModel(name: "smolVLM", configuration: VLMRegistry.smolvlminstruct4bit, type: .vlm),
        LMModel(name: "acereason:7B", configuration: LLMRegistry.acereason_7b_4bit, type: .llm),
        LMModel(name: "gemma3n:E2B", configuration: LLMRegistry.gemma3n_E2B_it_lm_4bit, type: .llm),
        LMModel(name: "gemma3n:E4B", configuration: LLMRegistry.gemma3n_E4B_it_lm_4bit, type: .llm),
    ]

    /// Currently loaded model container (single model mode for memory efficiency)
    private var currentModelContainer: (name: String, container: ModelContainer)?

    @MainActor public private(set) var modelDownloadProgress: Progress?

    public init() {}

    /// Unloads the current model and clears GPU memory
    private func unloadCurrentModel() {
        if currentModelContainer != nil {
            currentModelContainer = nil

            // Clear GPU cache to free memory
            MLX.GPU.clearCache()

            // Force garbage collection by setting a minimal cache limit temporarily
            let originalLimit = MLX.GPU.cacheLimit
            MLX.GPU.set(cacheLimit: 0)
            MLX.GPU.set(cacheLimit: originalLimit)
        }
    }

    private func load(model: LMModel) async throws -> ModelContainer {
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

        // Check if we already have this model loaded
        if let current = currentModelContainer, current.name == model.name {
            return current.container
        }

        // Unload previous model completely to free memory
        if let current = currentModelContainer, current.name != model.name {
            print("Unloading previous model: \(current.name)")
            unloadCurrentModel()
        }

        print("Loading new model: \(model.name)")
        let factory: ModelFactory = switch model.type { case .llm: LLMModelFactory.shared; case .vlm: VLMModelFactory.shared }
        let container = try await factory.loadContainer(hub: .default, configuration: model.configuration) { progress in
            Task { @MainActor in self.modelDownloadProgress = progress }
        }

        // Clear download progress after loading is complete
        Task { @MainActor in self.modelDownloadProgress = nil }

        // Store the new model container
        currentModelContainer = (model.name, container)
        print("Successfully loaded model: \(model.name)")
        return container
    }

    /// Manually unload the current model to free GPU memory
    /// This can be called when the app goes to background or when memory is needed
    public func unloadModel() {
        print("Manually unloading current model")
        unloadCurrentModel()
    }

    /// Get the name of the currently loaded model, if any
    public var currentlyLoadedModel: String? {
        return currentModelContainer?.name
    }

    /// Check if a specific model is currently loaded
    public func isModelLoaded(_ modelName: String) -> Bool {
        return currentModelContainer?.name == modelName
    }

    /// Generate a response from the model
    /// - Parameters:
    ///   - messages: The conversation messages
    ///   - model: The model to use for generation
    ///   - additionalContext: Optional context passed to the chat template (e.g., `["enable_thinking": false]` for Qwen3)
    /// - Returns: An async stream of generation events
    public func generate(
        messages: [Message],
        model: LMModel,
        additionalContext: [String: any Sendable]? = nil
    ) async throws -> AsyncStream<Generation> {
        let modelContainer = try await load(model: model)
        let chat = messages.map { message in
            let role: Chat.Message.Role = switch message.role { case .assistant: .assistant; case .user: .user; case .system: .system }
            let images: [UserInput.Image] = message.images.map { .url($0) }
            let videos: [UserInput.Video] = message.videos.map { .url($0) }
            return Chat.Message(role: role, content: message.content, images: images, videos: videos)
        }
        let userInput = UserInput(
            chat: chat,
            processing: .init(resize: .init(width: 1024, height: 1024)),
            additionalContext: additionalContext
        )
        return try await modelContainer.perform { (context: ModelContext) in
            let lmInput = try await context.processor.prepare(input: userInput)
            let parameters = GenerateParameters(temperature: 0.7)
            return try MLXLMCommon.generate(input: lmInput, parameters: parameters, context: context)
        }
    }

    /// Preload a model container so the next generation starts instantly
    /// - Parameter model: The model to load into memory
    public func preload(model: LMModel) async throws {
        _ = try await load(model: model)
    }

    /// Convenience to preload by name from the static registry
    /// - Parameter modelName: Name matching LMModel.name
    public func preload(modelName: String) async throws {
        guard let model = MLXService.availableModels.first(where: { $0.name == modelName }) else {
            throw NSError(domain: "MLXService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown model: \(modelName)"])
        }
        try await preload(model: model)
    }
}
