import AppKit
import XCTest
@testable import JSONPretty

/// 大文本渲染方案的回归守卫。
///
/// 背景（2026-10-13 实测，10MB 单行 JSON / macOS 26）：
/// - 窗口中直接 string= 赋值：~38s（CoreText 对单条巨型行排版 O(n²) 病理，
///   TextKit 1/2 同病，栈终点均为 _ctTypesetter 反复重建）
/// - 离屏赋值（摘除 documentView → 设置 → 放回）：0.33s
/// - 该实验数据记录于 docs/tasks.md T14
final class TextViewConfigBenchmarkTests: XCTestCase {
    static let fileURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("testdata/large-10mb.json")

    /// 守卫：离屏快路径必须保持亚秒级
    @MainActor
    func testDetachSetReattachFastPath() throws {
        let source = try String(contentsOf: Self.fileURL, encoding: .utf8)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 800),
                              styleMask: [.titled], backing: .buffered, defer: false)
        defer { window.close() }

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        let textView = NSTextView(frame: scrollView.bounds)
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                       height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        scrollView.documentView = textView
        window.contentView = scrollView
        window.orderFront(nil)

        // 分行展示 + 摘除-设置-放回（与 App 路径一致）
        let chunk = DisplayChunker.process(source)
        XCTAssertTrue(chunk.isChunked)

        let t = CFAbsoluteTimeGetCurrent()
        scrollView.documentView = nil
        textView.string = chunk.text
        scrollView.documentView = textView
        let total = CFAbsoluteTimeGetCurrent() - t
        print("⏱ [分行+离屏写入] \(String(format: "%.3f", total))s")
        XCTAssertLessThan(total, 2.0, "大文本写入快路径应在 2 秒内")

        window.orderOut(nil)
    }
}
