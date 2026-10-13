import Foundation

/// JSON 输出模式：格式化展开 / 压缩
enum JSONMode: String, Codable, CaseIterable {
    case pretty
    case compact

    var title: String { self == .pretty ? "格式化" : "压缩" }
}

/// 单个 Tab 的全部状态
struct JSONTab: Identifiable, Codable, Equatable {
    var id = UUID()
    /// 用户自定义名称（双击重命名设置）；默认按 T1..Tn 编号
    var customName: String?
    var input: String = ""
    var output: String = ""
    var errorMessage: String?
    var mode: JSONMode = .pretty
    var lastModified = Date()

    /// Tab 标题：优先自定义名称，否则取输入首个非空白片段，空则为“未命名”
    var title: String {
        if let customName, !customName.isEmpty { return customName }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "未命名" }
        let snippet = String(trimmed.prefix(24)).replacingOccurrences(of: "\n", with: " ")
        return snippet
    }
}
