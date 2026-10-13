import XCTest
@testable import JSONPretty

final class DisplayChunkerTests: XCTestCase {

    func testShortTextUnchanged() {
        let text = #"{"a":1,"b":[1,2,3]}"#
        let chunk = DisplayChunker.process(text)
        XCTAssertFalse(chunk.isChunked)
        XCTAssertEqual(chunk.text, text)
        XCTAssertTrue(chunk.breaks.isEmpty)
    }

    func testMultiLineNormalTextUnchanged() {
        // 多行但每行都不超长：不分行
        let line = String(repeating: "x", count: 1000)
        let text = (0..<100).map { _ in line }.joined(separator: "\n")
        let chunk = DisplayChunker.process(text)
        XCTAssertFalse(chunk.isChunked)
        XCTAssertEqual(chunk.text, text)
    }

    func testGiantLineIsChunkedAndRestorable() {
        // 10MB 单行：分行展示，剔除插入换行后必须精确还原
        let text = String(repeating: #"{"key":"value"},"#, count: 500_000)
        let chunk = DisplayChunker.process(text)
        XCTAssertTrue(chunk.isChunked)
        XCTAssertGreaterThan(chunk.breaks.count, 0)
        XCTAssertEqual(chunk.text.count, text.count + chunk.breaks.count)

        // 全文还原
        let restored = DisplayChunker.stripChunkBreaks(chunk.text, displayOffset: 0, breaks: chunk.breaks)
        XCTAssertEqual(restored, text)
    }

    func testMixedContentChunking() {
        let giantLine = String(repeating: "a", count: 100_000)
        let text = "short line\n\(giantLine)\nanother short"
        let chunk = DisplayChunker.process(text)
        XCTAssertTrue(chunk.isChunked)
        let restored = DisplayChunker.stripChunkBreaks(chunk.text, displayOffset: 0, breaks: chunk.breaks)
        XCTAssertEqual(restored, text)
    }

    func testPartialSelectionRestore() {
        // 模拟选区复制：跨越插入换行符的子串还原
        let text = String(repeating: "0123456789", count: 10_000) // 100KB 单行
        let chunk = DisplayChunker.process(text)
        XCTAssertTrue(chunk.isChunked)

        // 取展示文本中间一段（必然跨越多个插入的换行）
        let ns = chunk.text as NSString
        let displayRange = NSRange(location: 5000, length: 10_000)
        let substring = ns.substring(with: displayRange)
        let restored = DisplayChunker.stripChunkBreaks(substring,
                                                       displayOffset: displayRange.location,
                                                       breaks: chunk.breaks)

        // 换算回逻辑坐标：展示偏移 - 之前插入的换行数
        let breaksBefore = chunk.breaks.filter { $0 < displayRange.location }.count
        let logicalStart = displayRange.location - breaksBefore
        let expected = (text as NSString).substring(with: NSRange(location: logicalStart,
                                                                  length: restored.count))
        XCTAssertEqual(restored, expected)
    }

    func testEmojiAndUnicodeNotSplit() {
        // 分片边界不应劈开 grapheme（emoji/组合字符）
        let emojiLine = String(repeating: "🚀中a", count: 30_000) // ~90K 字符
        let chunk = DisplayChunker.process(emojiLine)
        XCTAssertTrue(chunk.isChunked)
        let restored = DisplayChunker.stripChunkBreaks(chunk.text, displayOffset: 0, breaks: chunk.breaks)
        XCTAssertEqual(restored, emojiLine)
        XCTAssertFalse(chunk.text.contains("\u{FFFD}"), "不应产生乱码替换符")
    }
}
