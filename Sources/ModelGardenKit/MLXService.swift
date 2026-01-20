import Foundation
import Observation
import MLX
import MLXLLM
import MLXLMCommon
import MLXVLM
import Tokenizers

// MARK: - Custom Model Configurations

extension ModelConfiguration {
    /// Jan-v1-4B: Agentic reasoning model based on Qwen3-4B-Thinking
    /// Fine-tuned for agentic tasks with tool calling capabilities
    /// Source: https://huggingface.co/mlx-community/Jan-v1-4B-4bit
    public static let janV1_4B_4bit = ModelConfiguration(
        id: "mlx-community/Jan-v1-4B-4bit",
        defaultPrompt: "You are a helpful AI assistant with agentic capabilities."
    )
    
    /// SmolLM3-3B: Efficient 3B parameter model from HuggingFace
    /// Supports 8 languages, Apache 2.0 licensed
    /// Source: https://huggingface.co/mlx-community/SmolLM3-3B-4bit
    public static let smolLM3_3B_4bit = ModelConfiguration(
        id: "mlx-community/SmolLM3-3B-4bit",
        defaultPrompt: "You are a helpful assistant."
    )
    
    /// Phi-4-mini-instruct: Microsoft's compact yet powerful model
    /// Source: https://huggingface.co/mlx-community/Phi-4-mini-instruct-4bit
    public static let phi4_mini_instruct_4bit = ModelConfiguration(
        id: "mlx-community/Phi-4-mini-instruct-4bit",
        defaultPrompt: "You are a helpful AI assistant."
    )
    
    /// Qwen3-4B-Instruct-2507: Latest Qwen3 4B instruct model (July 2025 version)
    /// Improved reasoning and instruction following
    /// Source: https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit
    public static let qwen3_4B_instruct_2507_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-4B-Instruct-2507-4bit",
        defaultPrompt: "You are a helpful assistant."
    )
}

@Observable
@MainActor
public final class MLXService {
    public static let availableModels: [LMModel] = [
        // Llama family - good tool calling support
        LMModel(name: "llama3.2:1b", configuration: LLMRegistry.llama3_2_1B_4bit, type: .llm, supportsToolCalling: true),
        
        // Qwen2.5 family - excellent tool support
        LMModel(name: "qwen2.5:1.5b", configuration: LLMRegistry.qwen2_5_1_5b, type: .llm, supportsToolCalling: true),
        
        // SmolLM - lightweight; SmolLM3 supports tool calling via XML tools
        LMModel(name: "smolLM:135m", configuration: LLMRegistry.smolLM_135M_4bit, type: .llm, supportsToolCalling: false),
        LMModel(name: "smolLM3:3b", configuration: .smolLM3_3B_4bit, type: .llm, supportsToolCalling: true),
        
        // Phi-4 mini - instruction tuned, supports structured output
        LMModel(name: "phi4-mini", configuration: .phi4_mini_instruct_4bit, type: .llm, supportsToolCalling: true),
        
        // Qwen3 family - excellent tool/function calling support
        LMModel(name: "qwen3:0.6b", configuration: LLMRegistry.qwen3_0_6b_4bit, type: .llm, supportsToolCalling: true),
        LMModel(name: "qwen3:1.7b", configuration: LLMRegistry.qwen3_1_7b_4bit, type: .llm, supportsToolCalling: true),
        LMModel(name: "qwen3:4b", configuration: LLMRegistry.qwen3_4b_4bit, type: .llm, supportsToolCalling: true),
        LMModel(name: "qwen3:4b-2507", configuration: .qwen3_4B_instruct_2507_4bit, type: .llm, supportsToolCalling: true),
        LMModel(name: "qwen3:8b", configuration: LLMRegistry.qwen3_8b_4bit, type: .llm, supportsToolCalling: true),
        
        // Jan-4b - based on Qwen3-4B-Thinking, optimized for agentic tasks with tool calling
        LMModel(name: "jan:4b", configuration: .janV1_4B_4bit, type: .llm, supportsToolCalling: true),
        
        // Vision models - Qwen2.5VL supports tool calling
        LMModel(name: "qwen2.5VL:3b", configuration: VLMRegistry.qwen2_5VL3BInstruct4Bit, type: .vlm, supportsToolCalling: true),
        LMModel(name: "qwen2VL:2b", configuration: VLMRegistry.qwen2VL2BInstruct4Bit, type: .vlm, supportsToolCalling: true),
        LMModel(name: "smolVLM", configuration: VLMRegistry.smolvlminstruct4bit, type: .vlm, supportsToolCalling: false),
        
        // AceReason - reasoning model, supports tool calling
        LMModel(name: "acereason:7B", configuration: LLMRegistry.acereason_7b_4bit, type: .llm, supportsToolCalling: true),
        
        // Gemma3n - Google's efficient models, supports tool calling
        LMModel(name: "gemma3n:E2B", configuration: LLMRegistry.gemma3n_E2B_it_lm_4bit, type: .llm, supportsToolCalling: true),
        LMModel(name: "gemma3n:E4B", configuration: LLMRegistry.gemma3n_E4B_it_lm_4bit, type: .llm, supportsToolCalling: true),
    ]

    /// Currently loaded model container (single model mode for memory efficiency)
    private var currentModelContainer: (name: String, container: ModelContainer)?
    
    /// Cache for loaded chat templates from .jinja files
    private var chatTemplateCache: [String: String] = [:]

    @MainActor public private(set) var modelDownloadProgress: Progress?

    public init() {}
    
    /// Load chat template from .jinja file in model directory if it exists
    private func loadChatTemplate(for configuration: ModelConfiguration) -> String? {
        let modelDir = configuration.modelDirectory(hub: .default)
        let jinjaPath = modelDir.appendingPathComponent("chat_template.jinja")
        
        // Check cache first
        let cacheKey = configuration.name
        if let cached = chatTemplateCache[cacheKey] {
            return cached
        }
        
        // Try to load from file
        if FileManager.default.fileExists(atPath: jinjaPath.path) {
            do {
                let template = try String(contentsOf: jinjaPath, encoding: .utf8)
                chatTemplateCache[cacheKey] = template
                print("MLXService: Loaded chat template from \(jinjaPath.lastPathComponent) (\(template.count) chars)")
                return template
            } catch {
                print("MLXService: Failed to load chat template: \(error)")
            }
        }
        
        return nil
    }
    
    /// Check if a model has a chat template with tool support
    public func modelHasToolTemplate(_ modelName: String) -> Bool {
        guard let model = MLXService.availableModels.first(where: { $0.name == modelName }) else {
            return false
        }
        if let template = loadChatTemplate(for: model.configuration) {
            return template.contains("tools") && template.contains("tool_call")
        }
        return false
    }

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
        
        do {
            let container = try await factory.loadContainer(hub: .default, configuration: model.configuration) { progress in
                Task { @MainActor in self.modelDownloadProgress = progress }
            }
            
            // Clear download progress after loading is complete
            Task { @MainActor in self.modelDownloadProgress = nil }
            
            // Store the new model container
            currentModelContainer = (model.name, container)
            print("Successfully loaded model: \(model.name)")
            return container
        } catch {
            // Log error to console with detailed information
            print("❌ MLXService: Failed to load model '\(model.name)'")
            print("   Model ID: \(model.configuration.name)")
            print("   Error: \(error)")
            print("   Localized: \(error.localizedDescription)")
            
            // Clear download progress on error
            Task { @MainActor in self.modelDownloadProgress = nil }
            
            // Re-throw the error so caller can handle it
            throw error
        }
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
    ///   - tools: Optional tool specifications for function calling (injected into chat template)
    ///   - maxTokens: Maximum tokens to generate (default 2048 for tool-calling models)
    ///   - additionalContext: Optional context passed to the chat template. Special keys:
    ///     - `"chatTemplate"`: A Jinja2 template string to override the model's default template
    ///     - `"enable_thinking"`: For Qwen3 models, set to false to disable thinking mode
    /// - Returns: An async stream of generation events
    public func generate(
        messages: [Message],
        model: LMModel,
        tools: [ToolSpec]? = nil,
        maxTokens: Int? = nil,
        additionalContext: [String: any Sendable]? = nil
    ) async throws -> AsyncStream<Generation> {
        let modelContainer = try await load(model: model)
        let chat = messages.map { message in
            let role: Chat.Message.Role = switch message.role { case .assistant: .assistant; case .user: .user; case .system: .system }
            let images: [UserInput.Image] = message.images.map { .url($0) }
            let videos: [UserInput.Video] = message.videos.map { .url($0) }
            return Chat.Message(role: role, content: message.content, images: images, videos: videos)
        }
        
        // Debug logging
        if let ctx = additionalContext {
            print("MLXService: additionalContext = \(ctx)")
        }
        if let tools = tools {
            print("MLXService: Passing \(tools.count) tools to chat template")
        }
        
        let userInput = UserInput(
            chat: chat,
            processing: .init(resize: .init(width: 1024, height: 1024)),
            tools: tools,
            additionalContext: additionalContext
        )
        return try await modelContainer.perform { (context: ModelContext) in
            // Use custom template processing if a chat template override is provided
            let lmInput: LMInput
            var effectiveContext = context
            
            if additionalContext?[ChatTemplateContextKey] != nil {
                lmInput = try await prepareWithCustomTemplate(input: userInput, context: context)
                
                // If extra EOS tokens are provided, create a modified context
                if let extraEOS = additionalContext?[ExtraEOSTokensContextKey] as? [String], !extraEOS.isEmpty {
                    effectiveContext = contextWithExtraEOSTokens(context, extraEOSTokens: extraEOS)
                }
            } else {
                lmInput = try await context.processor.prepare(input: userInput)
            }
            
            // Debug: print the prompt tokens count to see if tools are being injected
            print("MLXService: Prompt token count = \(lmInput.text.tokens.size)")
            
            // Use provided maxTokens or default to 2048 for tool-calling scenarios
            let effectiveMaxTokens = maxTokens ?? (tools != nil ? 2048 : nil)
            print("MLXService: effectiveMaxTokens = \(effectiveMaxTokens ?? -1)")
            
            // Use parameters optimized for tool calling (based on Jan model recommendations)
            // temperature: 0.6 for more focused reasoning, topP: 0.95 for coherent output
            let parameters = GenerateParameters(maxTokens: effectiveMaxTokens, temperature: 0.6, topP: 0.95)
            print("MLXService: Starting generation with temperature=0.6, topP=0.95")
            return try MLXLMCommon.generate(input: lmInput, parameters: parameters, context: effectiveContext)
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
