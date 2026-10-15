import XCTest
@testable import JSONPretty

@MainActor
final class AppStateTests: XCTestCase {

    func testDefaultTabNumbering() {
        let state = AppState()
        XCTAssertEqual(state.tabs.map(\.title), ["T1"])

        state.addTab()
        state.addTab()
        XCTAssertEqual(state.tabs.map(\.title), ["T1", "T2", "T3"])

        // 关闭 T2 后新建，编号不回收
        state.closeTab(state.tabs[1].id)
        state.addTab()
        XCTAssertEqual(state.tabs.map(\.title), ["T1", "T3", "T4"])
    }

    func testRenameTab() {
        let state = AppState()
        let id = state.tabs[0].id
        state.renameTab(id, name: "订单数据")
        XCTAssertEqual(state.tabs[0].title, "订单数据")

        // 空名称回退到内容推导 / 未命名
        state.renameTab(id, name: "   ")
        XCTAssertEqual(state.tabs[0].title, "Untitled")
    }

    func testMoveTab() {
        let state = AppState()
        state.addTab()
        state.addTab()
        // [T1, T2, T3] → 把 T1 拖到 T3 位置 → [T2, T3, T1]
        state.moveTab(state.tabs[0].id, onto: state.tabs[2].id)
        XCTAssertEqual(state.tabs.map(\.title), ["T2", "T3", "T1"])
    }

    func testMoveTabSameIDIsNoop() {
        let state = AppState()
        state.addTab()
        let before = state.tabs
        state.moveTab(state.tabs[0].id, onto: state.tabs[0].id)
        XCTAssertEqual(state.tabs, before)
    }

    func testCloseSelectedTabKeepsAtLeastOne() {
        let state = AppState()
        XCTAssertEqual(state.tabs.count, 1)
        state.closeSelectedTab()
        // 关闭最后一个 Tab 自动新建，且编号递增
        XCTAssertEqual(state.tabs.count, 1)
        XCTAssertEqual(state.tabs[0].title, "T2")
    }

    func testSearchIsIndependentPerTab() {
        let state = AppState()
        let t1Search = state.search
        t1Search.setQuery("alpha")
        t1Search.open()

        state.addTab()
        let t2Search = state.search
        XCTAssertTrue(t1Search !== t2Search, "每个 Tab 应有独立的搜索控制器")
        XCTAssertEqual(t2Search.query, "", "新 Tab 搜索应为空")
        XCTAssertFalse(t2Search.isVisible, "新 Tab 搜索栏默认关闭")

        // 切回 T1：搜索状态完整保留
        state.selectedTabID = state.tabs[0].id
        XCTAssertEqual(state.search.query, "alpha")
        XCTAssertTrue(state.search.isVisible)
    }

    func testSearchControllerRemovedOnTabClose() {
        let state = AppState()
        state.addTab()
        let t2Search = state.search
        t2Search.setQuery("beta")
        state.closeTab(state.tabs[1].id)
        // 关闭后回落到剩余 Tab 的控制器，且不为已关闭 Tab 保留状态
        XCTAssertEqual(state.search.query, "")
        XCTAssertEqual(state.tabs.count, 1)
    }

    func testSelectTabByIndex() {
        let state = AppState()
        state.addTab()
        state.addTab()
        // 当前选中 T3（最新）；⌘1 应切回 T1
        XCTAssertEqual(state.selectedTabID, state.tabs[2].id)
        state.selectTab(at: 0)
        XCTAssertEqual(state.selectedTabID, state.tabs[0].id)
        state.selectTab(at: 2)
        XCTAssertEqual(state.selectedTabID, state.tabs[2].id)
    }

    func testSelectTabOutOfBoundsIsNoop() {
        let state = AppState()
        let current = state.selectedTabID
        state.selectTab(at: 8) // 只有 1 个 Tab，⌘9 应无效果
        XCTAssertEqual(state.selectedTabID, current)
        state.selectTab(at: -1)
        XCTAssertEqual(state.selectedTabID, current)
    }
}
