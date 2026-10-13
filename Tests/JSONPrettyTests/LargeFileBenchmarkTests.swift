import AppKit
import XCTest
@testable import JSONPretty

/// 大文件性能基准：定位 10MB JSON 打开的瓶颈在哪一层
final class LargeFileBenchmarkTests: XCTestCase {
    static let fileURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // JSONPrettyTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // 项目根
        .appendingPathComponent("testdata/large-10mb.json")

    var source: String = ""

    override func setUpWithError() throws {
        source = try String(contentsOf: Self.fileURL, encoding: .utf8)
        XCTAssertGreaterThan(source.utf8.count, 9_000_000)
    }

    /// ① 解析层：10MB pretty / compact 耗时
    func testProcessorBenchmark() async throws {
        let processor = JSONProcessor()

        var t = CFAbsoluteTimeGetCurrent()
        let pretty = try await processor.format(source, mode: .pretty)
        let prettyTime = CFAbsoluteTimeGetCurrent() - t

        t = CFAbsoluteTimeGetCurrent()
        let compact = try await processor.format(source, mode: .compact)
        let compactTime = CFAbsoluteTimeGetCurrent() - t

        print("⏱ [10MB] pretty: \(String(format: "%.3f", prettyTime))s → \(pretty.utf8.count / 1_000_000)MB 输出")
        print("⏱ [10MB] compact: \(String(format: "%.3f", compactTime))s → \(compact.utf8.count / 1_000_000)MB 输出")
    }

    /// ② 渲染层：NSTextView 装载大文本耗时（与 App 一致的配置：不换行 + 非连续布局）
    /// 关键指标是“首屏可见区域排版耗时”——惰性布局下用户感知的时间
    @MainActor
    func testTextViewLayoutBenchmark() async throws {
        let processor = JSONProcessor()

        func measure(_ label: String, text: String, limit: Double) {
            let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
            textView.layoutManager?.allowsNonContiguousLayout = true
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                           height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = true

            var t = CFAbsoluteTimeGetCurrent()
            textView.string = text
            let setTime = CFAbsoluteTimeGetCurrent() - t

            // 只排版首屏 = 用户打开时的真实感知耗时
            t = CFAbsoluteTimeGetCurrent()
            let visibleRect = NSRect(x: 0, y: 0, width: 600, height: 800)
            let glyphs = textView.layoutManager!.glyphRange(forBoundingRect: visibleRect,
                                                            in: textView.textContainer!)
            textView.layoutManager?.ensureLayout(forGlyphRange: glyphs)
            let firstScreenTime = CFAbsoluteTimeGetCurrent() - t

            let total = setTime + firstScreenTime
            print("⏱ [\(label)] set=\(String(format: "%.3f", setTime))s 首屏排版=\(String(format: "%.3f", firstScreenTime))s 合计=\(String(format: "%.3f", total))s")
            XCTAssertLessThan(total, limit, "\(label) 首屏渲染应在 \(limit) 秒内")
        }

        let pretty = try await processor.format(source, mode: .pretty)
        // 单行 10MB：一次性字形生成约 1s，属 NSTextView 排版器下限
        measure("原始10MB单行", text: source, limit: 2.5)
        // 多行 18MB：惰性布局，应接近即时
        measure("格式化18MB多行", text: pretty, limit: 1.0)
    }
}
