import Foundation

/// JSON 解析/格式化处理器。
/// actor 隔离保证所有解析任务自动离开主线程，串行执行避免多 Tab 大文件互相争抢。
actor JSONProcessor {

    struct JSONError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// 将 JSON 文本按指定模式输出。
    /// - Throws: `JSONError`，message 含原始错误定位信息（行列号）。
    func format(_ text: String, mode: JSONMode) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard let data = trimmed.data(using: .utf8) else {
            throw JSONError(message: "Invalid text encoding")
        }

        // fragments 允许顶层为字符串/数字等标量
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch let error as NSError {
            // Foundation 的错误描述含 "around line X, column Y" 定位信息，直接透出
            let detail = (error.userInfo[NSDebugDescriptionErrorKey] as? String)
                ?? error.localizedDescription
            throw JSONError(message: "JSON parse failed: \(detail)")
        }

        guard JSONSerialization.isValidJSONObject(object) else {
            // 顶层标量：格式化即原样（压缩同理）
            return trimmed
        }

        var options: JSONSerialization.WritingOptions = [.withoutEscapingSlashes]
        if mode == .pretty {
            options.formUnion([.prettyPrinted])
        }

        do {
            let result = try JSONSerialization.data(withJSONObject: object, options: options)
            guard let string = String(data: result, encoding: .utf8) else {
                throw JSONError(message: "Failed to encode result")
            }
            return string
        } catch {
            throw JSONError(message: "JSON serialization failed: \(error.localizedDescription)")
        }
    }
}
