# ModelGarden (Standalone)

A standalone SwiftUI macOS app that uses the mlx-swift-examples libraries (MLXLLM/MLXVLM/MLXLMCommon) as a local Swift Package dependency. It provides:

- Chat screen similar to Applications/MLXChatExample
- Dedicated Model Manager to download/delete models via HubApi
- Theme settings and small shared UI kit

## Open & Run

- Open `Package.swift` in Xcode (File > Open).
- Choose the `ModelGardenApp` scheme and Run.

### macOS
- In the app target Signing & Capabilities, set the entitlements file to:
	`Sources/ModelGardenApp/ModelGardenApp.entitlements`
	This enables the increased memory limit (like the original MLXChatExample), sandbox, network, and Downloads access.
- Run on “My Mac”.

### iOS
- Select an iOS Simulator or a connected device and Run.
- Attachments are currently macOS-only; iOS media picker support can be enabled next.

## Dependencies

This package depends on the remote `mlx-swift-examples` repository (for MLXLLM/MLXVLM/MLXLMCommon) and on `swift-transformers` for Hub/Tokenizer types.

## Notes

- Models are stored under `~/Downloads/huggingface` on macOS by default (see HubApi+Default). On iOS they are stored in the app’s caches directory.
- The app targets macOS 14+ and uses Swift Concurrency with Observable macro.
