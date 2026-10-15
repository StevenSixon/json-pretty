import SwiftUI

/// 历史记录浮层：最近 10 个 Tab 的内容快照，可重新加载
struct HistoryView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent")
                    .font(.headline)
                Spacer()
                if !appState.history.isEmpty {
                    Button("Clear", role: .destructive) {
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
                ContentUnavailableView("No History",
                                       systemImage: "clock",
                                       description: Text("Closed tabs are kept here automatically"))
                    .frame(width: 320, height: 200)
            } else {
                List(appState.history) { entry in
                    Button {
                        appState.restoreFromHistory(entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.preview.isEmpty ? "(empty)" : entry.preview)
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
