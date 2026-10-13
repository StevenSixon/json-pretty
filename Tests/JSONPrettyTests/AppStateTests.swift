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
        XCTAssertEqual(state.tabs[0].title, "未命名")
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
}
