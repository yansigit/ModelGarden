import Foundation
import MLXLMCommon

public struct LMModel: Identifiable, Sendable, Hashable, Equatable {
    public let name: String
    public let configuration: ModelConfiguration
    public let type: ModelType
    
    /// Whether this model supports tool/function calling
    /// Models based on Qwen3, Llama3, Mistral, and other instruction-tuned models
    /// typically support the <tool_call> format for agentic interactions.
    public let supportsToolCalling: Bool

    public enum ModelType: Sendable { case llm, vlm }

    public init(name: String, configuration: ModelConfiguration, type: ModelType, supportsToolCalling: Bool = false) {
        self.name = name
        self.configuration = configuration
        self.type = type
        self.supportsToolCalling = supportsToolCalling
    }

    public var id: String { name }
    public var displayName: String { isVisionModel ? "\(name) (Vision)" : name }
    public var isLanguageModel: Bool { type == .llm }
    public var isVisionModel: Bool { type == .vlm }
}

public extension LMModel {
    static func == (lhs: LMModel, rhs: LMModel) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
}
