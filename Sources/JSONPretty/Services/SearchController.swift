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
    /// 聚焦请求令牌：⌘F 时递增（即使搜索栏已打开），视图层据此重新聚焦并全选
    private(set) var focusToken = 0
    /// 模糊匹配开关：开启后按“行内子序列”匹配；默认精确（子串）
    private(set) var fuzzy = false
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

    func toggleFuzzy() {
        fuzzy.toggle()
        currentIndex = 0
    }

    func open() {
        isVisible = true
        focusToken += 1 // 已打开时也要重新聚焦 + 全选
    }

    /// 关闭只隐藏搜索栏：查询词保留，下次 ⌘F 打开时自动全选便于替换输入
    func close() {
        isVisible = false
        currentIndex = 0
    }
}
