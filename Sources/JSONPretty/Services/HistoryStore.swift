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

/// 历史记录编解码与持久化文件位置。所有方法为同步实现，
/// 调用方须在后台线程执行（条目可能达 10MB 级，主线程 I/O 会卡 UI）。
enum HistoryStore {
    static let capacity = 10

    static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JSONPretty", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    static func load() -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([HistoryEntry].self, from: data)) ?? []
    }

    static func save(_ entries: [HistoryEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(entries) else { return }
        // 原子写：避免中途退出损坏历史文件
        try? data.write(to: fileURL, options: .atomic)
    }
}
