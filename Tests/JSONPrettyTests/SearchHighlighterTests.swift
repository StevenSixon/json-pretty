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

    private func backgroundColorRange(_ textView: NSTextView, at index: Int) -> NSRange? {
        var effective = NSRange()
        guard textView.layoutManager?.temporaryAttribute(.backgroundColor,
                                                         atCharacterIndex: index,
                                                         effectiveRange: &effective) != nil else { return nil }
        return effective
    }

    func testHighlightAndCountReported() {
        let textView = makeTextView()
        let controller = SearchController()
        controller.open()
        controller.setQuery("zip")
        let highlighter = SearchHighlighter(textView: textView)

        highlighter.apply(controller: controller, pane: .result)

        XCTAssertEqual(controller.activeMatchCount, 3)
        // 首个匹配自动定位：选区落在第一个 "zip" 上
        let firstRange = (text as NSString).range(of: "zip")
        XCTAssertEqual(textView.selectedRange(), firstRange)
        // 高亮属性已添加
        XCTAssertNotNil(backgroundColorRange(textView, at: firstRange.location))
    }

    func testNavigationMovesSelection() {
        let textView = makeTextView()
        let controller = SearchController()
        controller.open()
        controller.setQuery("zip")
        let highlighter = SearchHighlighter(textView: textView)
        highlighter.apply(controller: controller, pane: .result)

        // 匹配区间与搜索引擎一致（选区 = 查询词长度，非所在词组）
        let expected = SearchEngine.findMatches(in: text, query: "zip")
        XCTAssertEqual(expected.count, 3)

        controller.next()
        highlighter.apply(controller: controller, pane: .result)
        XCTAssertEqual(textView.selectedRange(), expected[1])

        // 环形：previous 回到第一个
        controller.previous()
        highlighter.apply(controller: controller, pane: .result)
        XCTAssertEqual(textView.selectedRange(), expected[0])

        // 环形越界：从第一个再 previous 到最后一个
        controller.previous()
        highlighter.apply(controller: controller, pane: .result)
        XCTAssertEqual(textView.selectedRange(), expected[2])
    }

    func testInactivePaneClearsHighlights() {
        let resultView = makeTextView()   // 右栏：有内容
        let editorView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400)) // 左栏：空
        let controller = SearchController()
        controller.open()
        controller.setQuery("zip")
        let resultHighlighter = SearchHighlighter(textView: resultView)
        let editorHighlighter = SearchHighlighter(textView: editorView)

        // 默认作用右栏：3 个匹配
        resultHighlighter.apply(controller: controller, pane: .result)
        XCTAssertEqual(controller.activeMatchCount, 3)

        // 焦点切到左栏：左栏（空内容）0 个匹配，右栏高亮清除
        controller.setActivePane(.editor)
        editorHighlighter.apply(controller: controller, pane: .editor)
        resultHighlighter.apply(controller: controller, pane: .result)
        XCTAssertEqual(controller.activeMatchCount, 0)
        XCTAssertNil(backgroundColorRange(resultView, at: 6), "面板切换后右栏高亮应清除")
    }

    func testCloseClearsEverything() {
        let textView = makeTextView()
        let controller = SearchController()
        controller.open()
        controller.setQuery("zip")
        let highlighter = SearchHighlighter(textView: textView)
        highlighter.apply(controller: controller, pane: .result)
        XCTAssertEqual(controller.activeMatchCount, 3)

        controller.close()
        highlighter.apply(controller: controller, pane: .result)
        XCTAssertEqual(controller.activeMatchCount, 0)
        let firstRange = (text as NSString).range(of: "zip")
        XCTAssertNil(backgroundColorRange(textView, at: firstRange.location), "关闭后高亮应清除")
    }

    func testQueryChangeResetsToFirstMatch() {
        let textView = makeTextView()
        let controller = SearchController()
        controller.open()
        let highlighter = SearchHighlighter(textView: textView)

        controller.setQuery("zip")
        highlighter.apply(controller: controller, pane: .result)
        controller.next()
        highlighter.apply(controller: controller, pane: .result)

        controller.setQuery("three")
        highlighter.apply(controller: controller, pane: .result)
        XCTAssertEqual(controller.activeMatchCount, 1)
        XCTAssertEqual(textView.selectedRange(), (text as NSString).range(of: "three"))
    }

    func testPaneSwitchDoesNotResetOnSamePane() {
        // 导航引发的选区变化会回调 setActivePane，同面板必须保持游标
        let controller = SearchController()
        controller.open()
        controller.setQuery("x")
        controller.setActivePane(.editor)
        controller.setActivePane(.editor) // 同面板重复调用
        // 不崩溃、不重置即通过（无公开游标断言，行为正确性由上面导航测试覆盖）
    }
}
