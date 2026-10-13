import AppKit
import UniformTypeIdentifiers

/// 打开 / 保存 JSON 文件的面板封装（面板必须在主线程弹出）
@MainActor
enum FileExporter {

    /// 打开 .json 文件，返回其文本内容（大文件在后台读取）
    static func openJSONFile() async -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return await Task.detached(priority: .userInitiated) {
            try? String(contentsOf: url, encoding: .utf8)
        }.value
    }

    /// 把文本保存为 .json 文件
    static func saveJSONFile(_ content: String, suggestedName: String = "formatted") {
        guard !content.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(suggestedName).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
}
