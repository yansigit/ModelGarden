import Foundation
import Observation
import MLXLLM
import MLXVLM
import MLXLMCommon

@Observable
@MainActor
public final class ModelManagerViewModel: @unchecked Sendable {
    public struct ModelStatus: Identifiable, Hashable, Sendable {
        public var id: String { model.id }
        public let model: LMModel
        public var isDownloaded: Bool
        public var sizeOnDisk: UInt64
        public var progress: Progress?
        
        public init(model: LMModel, isDownloaded: Bool, sizeOnDisk: UInt64, progress: Progress? = nil) {
            self.model = model
            self.isDownloaded = isDownloaded
            self.sizeOnDisk = sizeOnDisk
            self.progress = progress
        }
    }

    public private(set) var items: [ModelStatus] = []
    public var filter: LMModel.ModelType? = nil
    
    /// Tracks if refresh has been called at least once
    private var hasRefreshed = false

    public init() {
        // Don't call refresh() in init - it does expensive file system operations
        // that block the main thread. Call refresh() explicitly when needed.
    }
    
    /// Ensures items are populated. Call this before accessing items if they might not be loaded yet.
    public func refreshIfNeeded() {
        if !hasRefreshed {
            refresh()
        }
    }

    public func refresh() {
        hasRefreshed = true
        let all = MLXService.availableModels
        items = all.compactMap { model in
            let dir = model.configuration.modelDirectory(hub: .default)
            let exists = FileManager.default.fileExists(atPath: dir.path)
            let size = (try? dir.directorySize()) ?? 0
            return ModelStatus(model: model, isDownloaded: exists && size > 0, sizeOnDisk: size, progress: nil)
        }
    }

    public func download(_ model: LMModel, progressHandler: @Sendable @escaping (Progress) -> Void) async throws {
        // Use factories to trigger downloads; discard container and rely on Hub cache
        let factory: ModelFactory = switch model.type { case .llm: LLMModelFactory.shared; case .vlm: VLMModelFactory.shared }

        do {
            _ = try await factory.loadContainer(hub: .default, configuration: model.configuration) { progress in
                Task { @MainActor in
                    if let idx = self.items.firstIndex(where: { $0.model == model }) {
                        self.items[idx].progress = progress
                    }
                    progressHandler(progress)
                }
            }
        } catch let error as NSError where isCorruptedCacheError(error) {
            // Corrupted cache state detected - clean up and retry once
            print("ModelManagerViewModel: Detected corrupted cache for \(model.name), cleaning up and retrying...")
            cleanupCorruptedCache(for: model)

            // Retry the download after cleanup
            _ = try await factory.loadContainer(hub: .default, configuration: model.configuration) { progress in
                Task { @MainActor in
                    if let idx = self.items.firstIndex(where: { $0.model == model }) {
                        self.items[idx].progress = progress
                    }
                    progressHandler(progress)
                }
            }
        }
        await MainActor.run { self.refresh() }
    }

    /// Checks if an error indicates a corrupted HuggingFace cache state
    /// This happens when downloads are interrupted and .incomplete files are left in an inconsistent state
    private func isCorruptedCacheError(_ error: NSError) -> Bool {
        // NSCocoaErrorDomain Code=4 is NSFileNoSuchFileError (file not found during move operation)
        // The error message contains ".incomplete" which indicates a failed download resume
        if error.domain == NSCocoaErrorDomain && error.code == 4 {
            let errorDesc = error.localizedDescription + (error.userInfo[NSLocalizedDescriptionKey] as? String ?? "")
            return errorDesc.contains(".incomplete")
        }

        // Also check underlying POSIX error for "No such file or directory"
        if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlyingError.domain == NSPOSIXErrorDomain && underlyingError.code == 2 {
            return true
        }

        return false
    }

    /// Cleans up corrupted cache directories for a model
    /// Removes the .cache subdirectory and any .incomplete files that may be causing issues
    private func cleanupCorruptedCache(for model: LMModel) {
        let modelDir = model.configuration.modelDirectory(hub: .default)
        let fileManager = FileManager.default

        // Remove the .cache directory inside the model directory (this is where .incomplete files live)
        let cacheDir = modelDir.appendingPathComponent(".cache")
        if fileManager.fileExists(atPath: cacheDir.path) {
            do {
                try fileManager.removeItem(at: cacheDir)
                print("ModelManagerViewModel: Removed corrupted cache directory at \(cacheDir.path)")
            } catch {
                print("ModelManagerViewModel: Failed to remove cache directory: \(error)")
            }
        }

        // Also check for and remove any .incomplete files directly in the model directory
        if let enumerator = fileManager.enumerator(at: modelDir, includingPropertiesForKeys: nil) {
            while let url = enumerator.nextObject() as? URL {
                if url.lastPathComponent.contains(".incomplete") {
                    do {
                        try fileManager.removeItem(at: url)
                        print("ModelManagerViewModel: Removed incomplete file at \(url.path)")
                    } catch {
                        print("ModelManagerViewModel: Failed to remove incomplete file: \(error)")
                    }
                }
            }
        }

        // If the model directory exists but is essentially empty or corrupted, remove it entirely
        // This forces a fresh download
        if fileManager.fileExists(atPath: modelDir.path) {
            let size = (try? modelDir.directorySize()) ?? 0
            // If the directory is very small (less than 1MB), it's likely corrupted
            if size < 1_000_000 {
                do {
                    try fileManager.removeItem(at: modelDir)
                    print("ModelManagerViewModel: Removed corrupted model directory at \(modelDir.path)")
                } catch {
                    print("ModelManagerViewModel: Failed to remove model directory: \(error)")
                }
            }
        }
    }

    public func delete(_ model: LMModel) throws {
        let dir = model.configuration.modelDirectory(hub: .default)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
        refresh()
    }
}

private extension URL {
    func directorySize() throws -> UInt64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let enumerator = FileManager.default.enumerator(at: self, includingPropertiesForKeys: keys, options: [], errorHandler: nil)
        var total: UInt64 = 0
        while let url = enumerator?.nextObject() as? URL {
            let r = try url.resourceValues(forKeys: Set(keys))
            if r.isRegularFile == true, let fileSize = r.fileSize {
                total += UInt64(fileSize)
            }
        }
        return total
    }
}
