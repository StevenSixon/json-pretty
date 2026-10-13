import SwiftUI

/// 历史记录浮层：最近 10 个 Tab 的内容快照，可重新加载
struct HistoryView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("最近记录")
                    .font(.headline)
                Spacer()
                if !appState.history.isEmpty {
                    Button("清空", role: .destructive) {
                        appState.clearHistory()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if appState.history.isEmpty {
                ContentUnavailableView("暂无历史记录",
                                       systemImage: "clock",
                                       description: Text("关闭的 Tab 会自动保留在这里"))
                    .frame(width: 320, height: 200)
            } else {
                List(appState.history) { entry in
                    Button {
                        appState.restoreFromHistory(entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.preview.isEmpty ? "(空)" : entry.preview)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(2)
                                .truncationMode(.tail)
                            Text(entry.savedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 320, height: 320)
            }
        }
    }
}
