//
//  ModelSettings.swift
//  ModelGardenKit
//
//  User-configurable model generation settings
//

import Foundation
import Observation

/// User-configurable settings for model generation
@Observable
public final class ModelSettings: @unchecked Sendable {
    /// Custom EOS (End of Sequence) token(s) to stop generation
    /// Examples: "<|end|>", "<|eot_id|>", "</s>"
    /// Multiple tokens can be separated by commas
    public var customEOSTag: String = ""
    
    /// Returns the custom EOS tokens as an array for use with MLXService
    /// Parses comma-separated values and trims whitespace
    public var customEOSTokens: [String] {
        guard !customEOSTag.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return customEOSTag
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    public init() {}
}
