import XCTest
@testable import JSONPretty

@MainActor
final class SearchControllerTests: XCTestCase {

    func testEnterNavigatesNextRepeatedly() {
        // 模拟连续按回车：游标逐次前进并环形
        let controller = SearchController()
        controller.open()
        controller.setQuery("zip")

        // 回填 3 个匹配（模拟视图侧计算结果）
        controller.updateMatchCount(3, for: .result)
        XCTAssertEqual(controller.currentIndex, 0)

        controller.next() // 第 1 次回车
        XCTAssertEqual(controller.currentIndex, 1)
        controller.next() // 第 2 次回车
        XCTAssertEqual(controller.currentIndex, 2)
        controller.next() // 环形回绕
        XCTAssertEqual(controller.currentIndex, 0)
    }

    func testPreviousWrapsBackward() {
        let controller = SearchController()
        controller.open()
        controller.setQuery("x")
        controller.updateMatchCount(3, for: .result)

        controller.previous() // 从 0 向前 = 最后一个
        XCTAssertEqual(controller.currentIndex, 2)
    }

    func testNoMatchNavigationIsNoop() {
        let controller = SearchController()
        controller.next()
        controller.previous()
        XCTAssertEqual(controller.currentIndex, 0)
    }

    func testCloseKeepsQueryForReopenSelectAll() {
        let controller = SearchController()
        controller.open()
        controller.setQuery("keep-me")
        controller.close()
        XCTAssertEqual(controller.query, "keep-me", "关闭保留查询词，下次打开全选复用")
        XCTAssertFalse(controller.isVisible)
    }

    func testFuzzyToggleResetsCursor() {
        let controller = SearchController()
        controller.open()
        controller.updateMatchCount(5, for: .result)
        controller.next()
        XCTAssertFalse(controller.fuzzy)
        controller.toggleFuzzy()
        XCTAssertTrue(controller.fuzzy)
        XCTAssertEqual(controller.currentIndex, 0, "切换匹配模式应重置游标")
    }

    func testOpenIncrementsFocusTokenEvenWhenAlreadyVisible() {
        // 搜索栏已打开但失焦时，⌘F 必须再次触发聚焦请求
        let controller = SearchController()
        controller.open()
        let first = controller.focusToken
        controller.open() // 已打开状态下再次 ⌘F
        XCTAssertGreaterThan(controller.focusToken, first)
    }
}
