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
    }

    public private(set) var items: [ModelStatus] = []
    public var filter: LMModel.ModelType? = nil

    public init() {
        refresh()
    }

    public func refresh() {
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
        _ = try await factory.loadContainer(hub: .default, configuration: model.configuration) { progress in
            Task { @MainActor in
                if let idx = self.items.firstIndex(where: { $0.model == model }) {
                    self.items[idx].progress = progress
                }
                progressHandler(progress)
            }
        }
        await MainActor.run { self.refresh() }
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
