import Foundation

/// 搜索状态：查询词、目标面板、当前匹配游标。高亮/滚动由各面板视图侧执行。
@MainActor
@Observable
final class SearchController {
    enum Pane {
        case editor, result
    }

    var query = ""
    var isVisible = false
    /// 当前搜索作用的面板：跟随焦点，默认右侧结果区
    private(set) var activePane: Pane = .result
    /// 当前匹配下标（active pane 的匹配列表内）
    private(set) var currentIndex = 0
    /// 各面板匹配数（由视图侧计算后回填）
    private(set) var matchCounts: [Pane: Int] = [:]

    var activeMatchCount: Int { matchCounts[activePane] ?? 0 }

    func setQuery(_ newQuery: String) {
        query = newQuery
        currentIndex = 0
    }

    /// 焦点切换面板时跟随；面板不变则不动游标（导航引发的选区变化不应重置）
    func setActivePane(_ pane: Pane) {
        guard activePane != pane else { return }
        activePane = pane
        currentIndex = 0
    }

    func updateMatchCount(_ count: Int, for pane: Pane) {
        matchCounts[pane] = count
        if pane == activePane, currentIndex >= count {
            currentIndex = 0
        }
    }

    func next() {
        guard activeMatchCount > 0 else { return }
        currentIndex = (currentIndex + 1) % activeMatchCount
    }

    func previous() {
        guard activeMatchCount > 0 else { return }
        currentIndex = (currentIndex - 1 + activeMatchCount) % activeMatchCount
    }

    func open() {
        isVisible = true
    }

    func close() {
        isVisible = false
        query = ""
        currentIndex = 0
        matchCounts = [:]
    }
}
