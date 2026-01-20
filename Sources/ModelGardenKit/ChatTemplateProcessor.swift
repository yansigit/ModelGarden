//
//  ChatTemplateProcessor.swift
//  ModelGardenKit
//
//  Custom chat template support for overriding the model's default template
//

import Foundation
import MLX
import MLXLMCommon
import Tokenizers

/// Key used in additionalContext to specify a custom chat template (Jinja2 string)
public let ChatTemplateContextKey = "chatTemplate"

/// Key used in additionalContext to specify extra EOS tokens for custom templates
public let ExtraEOSTokensContextKey = "extraEOSTokens"

/// Prepare LMInput using a custom chat template
///
/// This function handles the chat template override logic:
/// - If a custom template is provided via additionalContext["chatTemplate"],
///   it uses that template with the tokenizer's applyChatTemplate method
/// - Otherwise, it delegates to the default processor
///
/// - Parameters:
///   - input: The UserInput to process
///   - context: The ModelContext containing the tokenizer and processor
/// - Returns: LMInput ready for generation
public func prepareWithCustomTemplate(
    input: UserInput,
    context: ModelContext
) async throws -> LMInput {
    // Check if a custom chat template is provided in additionalContext
    let customTemplate = input.additionalContext?[ChatTemplateContextKey] as? String
    
    guard let template = customTemplate, !template.isEmpty else {
        // No custom template, use the default processor
        return try await context.processor.prepare(input: input)
    }
    
    // Custom template provided - apply it directly using the tokenizer
    print("ChatTemplateProcessor: Using custom chat template (\(template.count) chars)")
    
    // Generate messages using the same approach as the default processor
    let messages = generateMessages(from: input)
    
    // Filter out the chatTemplate key from additionalContext before passing to tokenizer
    let filteredContext = input.additionalContext?.filter { $0.key != ChatTemplateContextKey }
    
    do {
        let promptTokens = try context.tokenizer.applyChatTemplate(
            messages: messages,
            chatTemplate: .literal(template),
            addGenerationPrompt: true,
            truncation: false,
            maxLength: nil,
            tools: input.tools,
            additionalContext: filteredContext
        )
        return LMInput(tokens: MLXArray(promptTokens))
    } catch TokenizerError.chatTemplate(let message) {
        print("ChatTemplateProcessor: Chat template error: \(message)")
        print("ChatTemplateProcessor: Falling back to default processor")
        return try await context.processor.prepare(input: input)
    }
}

/// Create a modified ModelContext with extra EOS tokens for custom chat templates
///
/// When using a custom chat template, the model may generate different EOS markers
/// than its native ones. This function creates a new context with the custom template's
/// EOS tokens added to the configuration.
///
/// - Parameters:
///   - context: The original ModelContext
///   - extraEOSTokens: Additional EOS tokens to recognize (from the custom template)
/// - Returns: A new ModelContext with the extra EOS tokens configured
public func contextWithExtraEOSTokens(
    _ context: ModelContext,
    extraEOSTokens: [String]
) -> ModelContext {
    // Merge existing extra EOS tokens with new ones
    var allExtraEOS = context.configuration.extraEOSTokens
    for token in extraEOSTokens {
        allExtraEOS.insert(token)
    }
    
    print("ChatTemplateProcessor: Adding extra EOS tokens: \(extraEOSTokens)")
    print("ChatTemplateProcessor: Total extra EOS tokens: \(allExtraEOS)")
    
    // Create a new configuration with the combined EOS tokens
    // ModelConfiguration.id is an Identifier enum, need to handle both cases
    let newConfiguration: ModelConfiguration
    switch context.configuration.id {
    case .id(let id, let revision):
        newConfiguration = ModelConfiguration(
            id: id,
            revision: revision,
            extraEOSTokens: allExtraEOS
        )
    case .directory(let url):
        newConfiguration = ModelConfiguration(
            directory: url,
            extraEOSTokens: allExtraEOS
        )
    }
    
    // Create and return a new context with the updated configuration
    return ModelContext(
        configuration: newConfiguration,
        model: context.model,
        processor: context.processor,
        tokenizer: context.tokenizer
    )
}

/// Generate messages array from UserInput in the format expected by the tokenizer
/// This replicates the basic message generation logic
private func generateMessages(from input: UserInput) -> [[String: any Sendable]] {
    switch input.prompt {
    case .text(let text):
        return [["role": "user", "content": text]]
        
    case .messages(let messages):
        return messages
        
    case .chat(let chatMessages):
        return chatMessages.map { message -> [String: any Sendable] in
            let dict: [String: any Sendable] = [
                "role": message.role.rawValue,
                "content": message.content
            ]
            return dict
        }
    }
}

