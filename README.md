# ModelGarden

A Swift library and application for running large language models (LLMs) and vision language models (VLMs) locally on Apple devices using MLX.

## Overview

ModelGarden provides a complete solution for local AI inference on macOS and iOS:

- **ModelGardenKit** - A reusable Swift library for integrating local LLM/VLM inference into your apps
- **ModelGardenApp** - A fully-featured SwiftUI application demonstrating the library's capabilities

All models run entirely on-device using Apple's MLX framework with GPU acceleration on Apple Silicon.

## Features

- **Local Inference** - Run AI models entirely on-device with no internet required after download
- **Streaming Generation** - Real-time token streaming with performance metrics
- **Vision Model Support** - Handle both text-only LLMs and vision-capable VLMs
- **Model Management** - Download, cache, and delete models with progress tracking
- **Cross-Platform** - Runs on macOS 14+ and iOS 17+
- **Memory Efficient** - 4-bit quantized models with automatic GPU memory management
- **SwiftUI Ready** - Observable view models for seamless UI integration

## Requirements

- macOS 14.0+ or iOS 17.0+
- Apple Silicon (M1 or later recommended)
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add ModelGarden to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/anthropics/ModelGarden.git", from: "0.1.0")
]
```

Then add the library to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "ModelGardenKit", package: "ModelGarden")
    ]
)
```

### Local Development

Clone the repository and open in Xcode:

```bash
git clone https://github.com/anthropics/ModelGarden.git
cd ModelGarden
open Package.swift
```

## Project Structure

```
ModelGarden/
├── Package.swift                          # Swift Package manifest
├── Sources/
│   ├── ModelGardenKit/                   # Core library (reusable framework)
│   │   ├── LMModel.swift                 # Model definitions & registry
│   │   ├── Message.swift                 # Chat message model with media
│   │   ├── MLXService.swift              # Inference engine & model loading
│   │   ├── ChatViewModel.swift           # Chat state management
│   │   ├── ModelManagerViewModel.swift   # Model download/delete logic
│   │   └── HubApi+Default.swift          # Hugging Face Hub configuration
│   │
│   └── ModelGardenApp/                   # SwiftUI application
│       ├── App.swift                     # Entry point
│       ├── RootView.swift                # Tab navigation
│       ├── Screens/
│       │   ├── ChatScreen.swift          # Chat interface
│       │   ├── ModelManagerScreen.swift  # Model browser
│       │   └── SettingsScreen.swift      # Theme settings
│       └── Shared/
│           └── Components.swift          # Reusable UI components
```

## Available Models

ModelGarden comes preconfigured with 13 models optimized for on-device inference:

### Language Models (LLMs)

| Model | Parameters | Description |
|-------|------------|-------------|
| llama3.2:1b | 1B | Meta's Llama 3.2 (compact) |
| qwen2.5:1.5b | 1.5B | Alibaba's Qwen 2.5 |
| qwen3:0.6b | 0.6B | Qwen 3 (tiny) |
| qwen3:1.7b | 1.7B | Qwen 3 (small) |
| qwen3:4b | 4B | Qwen 3 (medium) |
| qwen3:8b | 8B | Qwen 3 (large) |
| smolLM:135m | 135M | HuggingFace SmolLM |
| acereason:7B | 7B | ACEReason reasoning model |
| gemma3n:E2B | ~2B | Google Gemma 3 Nano |
| gemma3n:E4B | ~4B | Google Gemma 3 Nano |

### Vision Language Models (VLMs)

| Model | Parameters | Description |
|-------|------------|-------------|
| qwen2.5VL:3b | 3B | Qwen 2.5 VL (vision-capable) |
| qwen2VL:2b | 2B | Qwen 2 VL (vision-capable) |
| smolVLM | ~1B | HuggingFace SmolVLM |

All models use 4-bit quantization for optimal memory efficiency.

## Usage

### Basic Chat Generation

```swift
import ModelGardenKit

// Create the MLX service
let service = MLXService()

// Select a model
let model = MLXService.availableModels.first { $0.name == "qwen3:1.7b" }!

// Create messages
let messages = [
    Message.system("You are a helpful assistant."),
    Message.user("What is Swift?")
]

// Generate response with streaming
for await generation in service.generate(messages: messages, model: model) {
    switch generation {
    case .chunk(let text):
        print(text, terminator: "")
    case .done(let output):
        print("\n\nTokens/sec: \(output.tokensPerSecond)")
    }
}
```

### Using ChatViewModel for SwiftUI

```swift
import SwiftUI
import ModelGardenKit

struct ChatView: View {
    @State private var viewModel = ChatViewModel()

    var body: some View {
        VStack {
            // Display messages
            ScrollView {
                ForEach(viewModel.messages) { message in
                    MessageBubble(message: message)
                }
            }

            // Input field
            HStack {
                TextField("Message", text: $viewModel.prompt)

                Button("Send") {
                    Task {
                        await viewModel.generate()
                    }
                }
                .disabled(viewModel.isGenerating)
            }
        }
    }
}
```

### Model Management

```swift
import ModelGardenKit

let manager = ModelManagerViewModel()

// Refresh to check which models are downloaded
manager.refresh()

// Check model status
for status in manager.items {
    print("\(status.model.name): \(status.isDownloaded ? "Downloaded" : "Not downloaded")")
    if status.isDownloaded {
        print("  Size: \(status.sizeOnDisk) bytes")
    }
}

// Download a model
let model = MLXService.availableModels.first { $0.name == "smolLM:135m" }!
try await manager.download(model)

// Delete a model
try manager.delete(model)
```

### Preloading Models

For faster first response, preload models before the user starts chatting:

```swift
let service = MLXService()

// Preload by model object
await service.preload(model: selectedModel)

// Or preload by name
await service.preload(modelName: "qwen3:1.7b")

// Check what's currently loaded
if let loaded = service.currentlyLoadedModel {
    print("Currently loaded: \(loaded)")
}
```

### Vision Model Usage (macOS)

```swift
import ModelGardenKit

let viewModel = ChatViewModel()

// Select a vision model
viewModel.selectedModel = MLXService.availableModels.first { $0.type == .vlm }!

// Add an image
let imageURL = URL(fileURLWithPath: "/path/to/image.jpg")
viewModel.addMedia(.success(imageURL))

// Set the prompt
viewModel.prompt = "Describe this image"

// Generate
await viewModel.generate()
```

### Memory Management

ModelGarden automatically manages GPU memory, but you can manually control it:

```swift
let service = MLXService()

// Unload the current model to free memory
service.unloadModel()

// Check if a specific model is loaded
if service.isModelLoaded("qwen3:1.7b") {
    print("Model is ready")
}
```

## API Reference

### MLXService

The core inference engine.

```swift
@Observable @MainActor
public final class MLXService {
    /// All available models
    static var availableModels: [LMModel]

    /// Currently loaded model name (nil if none)
    var currentlyLoadedModel: String?

    /// Progress for model downloads
    var modelDownloadProgress: Progress?

    /// Generate a response from messages
    func generate(messages: [Message], model: LMModel) -> AsyncStream<Generation>

    /// Preload a model for faster inference
    func preload(model: LMModel) async
    func preload(modelName: String) async

    /// Unload the current model and free memory
    func unloadModel()

    /// Check if a model is loaded
    func isModelLoaded(_ name: String) -> Bool
}
```

### Message

Represents a chat message with optional media attachments.

```swift
@Observable
public final class Message: Identifiable {
    var role: Role        // .user, .assistant, .system
    var content: String   // Message text
    var images: [URL]     // Image attachments
    var videos: [URL]     // Video attachments
    var timestamp: Date

    // Convenience constructors
    static func user(_ content: String) -> Message
    static func assistant(_ content: String) -> Message
    static func system(_ content: String) -> Message
}
```

### LMModel

Model definition with metadata.

```swift
public struct LMModel: Identifiable, Sendable, Hashable {
    var name: String              // e.g., "qwen3:1.7b"
    var configuration: ModelConfiguration
    var type: ModelType           // .llm or .vlm
    var displayName: String       // Human-readable name
}
```

### ChatViewModel

Complete chat state management for SwiftUI.

```swift
@Observable @MainActor
public final class ChatViewModel {
    var messages: [Message]
    var selectedModel: LMModel
    var prompt: String
    var isGenerating: Bool
    var tokensPerSecond: Double
    var errorMessage: String?

    func generate() async
    func clear(_ options: ClearOption)
    func addMedia(_ result: Result<URL, Error>)
}
```

### ModelManagerViewModel

Model lifecycle management.

```swift
@Observable @MainActor
public final class ModelManagerViewModel {
    var items: [ModelStatus]      // All models with download state
    var filter: LMModel.ModelType? // Filter by LLM/VLM

    func refresh()
    func download(_ model: LMModel) async throws
    func delete(_ model: LMModel) throws
}
```

## Platform Differences

| Feature | macOS 14+ | iOS 17+ |
|---------|-----------|---------|
| Core inference | Yes | Yes |
| Chat interface | Yes | Yes |
| Model manager | Yes | Yes |
| Image attachments | Yes | No |
| Video attachments | Yes | No |
| Model storage path | ~/Downloads/huggingface/ | {Caches}/huggingface/ |

## Building the App

### macOS

```bash
swift build -c release
```

Or open in Xcode and build the `ModelGardenApp` scheme.

### iOS

Build via Xcode with the `ModelGardenApp` scheme targeting an iOS device or simulator.

### Entitlements (macOS)

The app requires these entitlements for full functionality:
- Increased memory limit (for large models)
- App Sandbox
- Downloads folder access
- Network client (for model downloads)

## Dependencies

- [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) - MLX Swift bindings for LLM/VLM inference
- [swift-transformers](https://github.com/huggingface/swift-transformers) - Hugging Face Hub API and tokenizers

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]
