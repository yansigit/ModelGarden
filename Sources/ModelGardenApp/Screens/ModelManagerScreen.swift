import SwiftUI
import ModelGardenKit

struct ModelManagerScreen: View {
    @State private var vm = ModelManagerViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Picker("Filter", selection: $vm.filter) {
                        Text("All").tag(LMModel.ModelType?.none)
                        Text("LLM").tag(LMModel.ModelType?.some(.llm))
                        Text("VLM").tag(LMModel.ModelType?.some(.vlm))
                    }
                    .pickerStyle(.segmented)
                    Spacer()
                    Button { vm.refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                }.padding()

                List {
                    ForEach(vm.items.filter { vm.filter == nil || $0.model.type == vm.filter }) { item in
                        ModelRow(item: item, onDownload: { model in
                            Task { try? await vm.download(model) { _ in } }
                        }, onDelete: { model in
                            try? vm.delete(model)
                        })
                    }
                }
            }
            .navigationTitle("Models")
            .onAppear {
                vm.refreshIfNeeded()
            }
        }
    }
}

struct ModelRow: View {
    var item: ModelManagerViewModel.ModelStatus
    var onDownload: (LMModel) -> Void
    var onDelete: (LMModel) -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.1)).frame(width: 44, height: 44)
                .overlay(Image(systemName: item.model.isVisionModel ? "eye.fill" : "textformat.alt").font(.title3))
            VStack(alignment: .leading) {
                Text(item.model.displayName).font(.headline)
                HStack(spacing: 8) {
                    if item.isDownloaded {
                        Label(ByteCountFormatter.string(fromByteCount: Int64(item.sizeOnDisk), countStyle: .file), systemImage: "externaldrive.fill").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Not downloaded").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let p = item.progress { DownloadProgressView(progress: p) }
            }
            Spacer()
            if item.isDownloaded {
                Button(role: .destructive) { onDelete(item.model) } label: { Label("Delete", systemImage: "trash") }
            } else {
                Button { onDownload(item.model) } label: { Label("Download", systemImage: "arrow.down.circle.fill") }
            }
        }
        .padding(.vertical, 6)
    }
}

struct DownloadProgressView: View {
    var progress: Progress
    var body: some View {
        VStack(alignment: .leading) {
            ProgressView(value: progress.fractionCompleted)
                .progressViewStyle(.linear)
            HStack {
                Text("\(Int(progress.fractionCompleted*100))%")
                Spacer()
                Text("\(progress.completedUnitCount)/\(progress.totalUnitCount)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}
