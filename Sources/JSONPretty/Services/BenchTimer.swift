import Foundation

/// 真实 App 内的分阶段计时。通过启动参数启用：
///   JSONPretty --bench <json文件路径>
/// 启动后自动把文件载入首个 Tab，并在各阶段打印相对耗时。
enum BenchTimer {
    static let filePath: String? = {
        guard let index = CommandLine.arguments.firstIndex(of: "--bench"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }()

    static var enabled: Bool { filePath != nil }

    private static let start = CFAbsoluteTimeGetCurrent()

    static func mark(_ label: String) {
        guard enabled else { return }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        print(String(format: "⏱ [BENCH %7.3fs] %@", elapsed, label))
        fflush(stdout)
    }
}
