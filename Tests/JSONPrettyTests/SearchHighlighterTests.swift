import AppKit
import XCTest
@testable import JSONPretty

@MainActor
final class SearchHighlighterTests: XCTestCase {

    private let text = #"{"a":"zip-one","b":"zip-two","c":"zip-three"}"#

    private func makeTextView() -> NSTextView {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        textView.string = text
        return textView
    }

    /// 搜索为 200ms 防抖 + 后台计算；测试侧等待结果落地
    private func applyAndWait(_ highlighter: SearchHighlighter,
                              controller: SearchController,
                              pane: SearchController.Pane) async {
        highlighter.apply(controller: controller, pane: pane)
        try? await Task.sleep(for: .milliseconds(400))
    }

    private func backgroundColorRange(_ textView: NSTextView, at index: Int) -> NSRange? {
        var effective = NSRange()
        guard textView.layoutManager?.temporaryAttribute(.backgroundColor,
                                                         atCharacterIndex: index,
                                                         effectiveRange: &effective) != nil else { return nil }
        return effective
    }

    func testHighlightAndCountReported() async {
        let textView = makeTextView()
        let controller = SearchController()
        controller.open()
        controller.setQuery("zip")
        let highlighter = SearchHighlighter(textView: textView)

        await applyAndWait(highlighter, controller: controller, pane: .result)

        XCTAssertEqual(controller.activeMatchCount, 3)
        let firstRange = (text as NSString).range(of: "zip")
        XCTAssertEqual(textView.selectedRange(), firstRange)
        XCTAssertNotNil(backgroundColorRange(textView, at: firstRange.location))
    }

    func testNavigationMovesSelection() async {
        let textView = makeTextView()
        let controller = SearchController()
        controller.open()
        controller.setQuery("zip")
        let highlighter = SearchHighlighter(textView: textView)
        await applyAndWait(highlighter, controller: controller, pane: .result)

        let expected = SearchEngine.findMatches(in: text, query: "zip")
        XCTAssertEqual(expected.count, 3)

        controller.next()
        highlighter.apply(controller: controller, pane: .result)
        XCTAssertEqual(textView.selectedRange(), expected[1])

        controller.previous()
        highlighter.apply(controller: controller, pane: .result)
        XCTAssertEqual(textView.selectedRange(), expected[0])

        // 环形越界：从第一个再 previous 到最后一个
        controller.previous()
        highlighter.apply(controller: controller, pane: .result)
        XCTAssertEqual(textView.selectedRange(), expected[2])
    }

    func testInactivePaneClearsHighlights() async {
        let resultView = makeTextView()
        let editorView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let controller = SearchController()
        controller.open()
        controller.setQuery("zip")
        let resultHighlighter = SearchHighlighter(textView: resultView)
        let editorHighlighter = SearchHighlighter(textView: editorView)

        await applyAndWait(resultHighlighter, controller: controller, pane: .result)
        XCTAssertEqual(controller.activeMatchCount, 3)

        controller.setActivePane(.editor)
        await applyAndWait(editorHighlighter, controller: controller, pane: .editor)
        resultHighlighter.apply(controller: controller, pane: .result)
        XCTAssertEqual(controller.activeMatchCount, 0)
        XCTAssertNil(backgroundColorRange(resultView, at: 6), "面板切换后右栏高亮应清除")
    }

    func testCloseKeepsQueryButClearsHighlights() async {
        let textView = makeTextView()
        let controller = SearchController()
        controller.open()
        controller.setQuery("zip")
        let highlighter = SearchHighlighter(textView: textView)
        await applyAndWait(highlighter, controller: controller, pane: .result)
        XCTAssertEqual(controller.activeMatchCount, 3)

        controller.close()
        highlighter.apply(controller: controller, pane: .result)
        XCTAssertEqual(controller.query, "zip", "关闭后查询词应保留（下次打开自动全选）")
        let firstRange = (text as NSString).range(of: "zip")
        XCTAssertNil(backgroundColorRange(textView, at: firstRange.location), "关闭后高亮应清除")
    }

    func testQueryChangeResetsToFirstMatch() async {
        let textView = makeTextView()
        let controller = SearchController()
        controller.open()
        let highlighter = SearchHighlighter(textView: textView)

        controller.setQuery("zip")
        await applyAndWait(highlighter, controller: controller, pane: .result)
        controller.next()
        highlighter.apply(controller: controller, pane: .result)

        controller.setQuery("three")
        await applyAndWait(highlighter, controller: controller, pane: .result)
        XCTAssertEqual(controller.activeMatchCount, 1)
        XCTAssertEqual(textView.selectedRange(), (text as NSString).range(of: "three"))
    }

    func testStaleSearchResultDiscarded() async {
        let textView = makeTextView()
        let controller = SearchController()
        controller.open()
        let highlighter = SearchHighlighter(textView: textView)

        // 快速连续变更查询词：只有最后一个结果生效
        controller.setQuery("zip")
        highlighter.apply(controller: controller, pane: .result)
        controller.setQuery("one")
        highlighter.apply(controller: controller, pane: .result)
        controller.setQuery("three")
        highlighter.apply(controller: controller, pane: .result)

        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(controller.activeMatchCount, 1)
        XCTAssertEqual(textView.selectedRange(), (text as NSString).range(of: "three"))
    }
}
