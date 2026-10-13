import Foundation

/// 历史记录条目：某个 Tab 的最终内容快照
struct HistoryEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    let input: String
    let mode: JSONMode
    let savedAt: Date

    var preview: String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(60)).replacingOccurrences(of: "\n", with: " ")
    }
}

/// 历史持久化：环形保留最近 10 条，JSON 原子写入 Application Support。
final class HistoryStore {
    static let capacity = 10

    private(set) var entries: [HistoryEntry] = []
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JSONPretty", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")
        load()
    }

    func push(_ tab: JSONTab) {
        let entry = HistoryEntry(input: tab.input, mode: tab.mode, savedAt: Date())
        entries.insert(entry, at: 0)
        if entries.count > Self.capacity {
            entries = Array(entries.prefix(Self.capacity))
        }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([HistoryEntry].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(entries) else { return }
        // 原子写：避免中途退出损坏历史文件
        try? data.write(to: fileURL, options: .atomic)
    }
}
