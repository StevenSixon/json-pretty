import AppKit

/// 搜索高亮器：供编辑器/结果区两个面板的 Coordinator 复用。
/// 负责匹配缓存、临时属性高亮、当前匹配加深与滚动定位。
@MainActor
final class SearchHighlighter {
    private static let matchColor = NSColor.systemYellow.withAlphaComponent(0.35)
    private static let currentColor = NSColor.systemOrange.withAlphaComponent(0.55)

    private weak var textView: NSTextView?
    private var matches: [NSRange] = []
    private var lastQuery: String?
    private var lastString: String?
    private var lastLength = 0
    private var lastCurrentIndex = -1

    init(textView: NSTextView) {
        self.textView = textView
    }

    /// 每个面板在 updateNSView 末尾调用。内部缓存保证幂等，重复调用零成本。
    func apply(controller: SearchController, pane: SearchController.Pane) {
        guard let textView, let layoutManager = textView.layoutManager else { return }
        let string = textView.string
        let isActive = controller.isVisible && controller.activePane == pane && !controller.query.isEmpty

        guard isActive else {
            if lastQuery != nil {
                removeHighlights(on: layoutManager, length: max(lastLength, (string as NSString).length))
                lastQuery = nil
                lastString = nil
                lastLength = 0
                matches = []
                lastCurrentIndex = -1
                controller.updateMatchCount(0, for: pane)
            }
            return
        }

        // 内容或查询词变化时重算匹配并刷新高亮
        if controller.query != lastQuery || string != lastString {
            removeHighlights(on: layoutManager, length: max(lastLength, (string as NSString).length))
            lastQuery = controller.query
            lastString = string
            lastLength = (string as NSString).length
            matches = SearchEngine.findMatches(in: string, query: controller.query)
            controller.updateMatchCount(matches.count, for: pane)
            lastCurrentIndex = -1
            // 超过高亮上限只导航不高亮，避免海量临时属性拖慢排版
            if matches.count <= SearchEngine.highlightCap {
                for range in matches {
                    layoutManager.addTemporaryAttribute(.backgroundColor,
                                                        value: Self.matchColor,
                                                        forCharacterRange: range)
                }
            }
        }

        showCurrent(controller.currentIndex, on: textView, layoutManager: layoutManager)
    }

    private func showCurrent(_ index: Int, on textView: NSTextView, layoutManager: NSLayoutManager) {
        guard !matches.isEmpty else { return }
        let clamped = ((index % matches.count) + matches.count) % matches.count
        guard clamped != lastCurrentIndex else { return }

        // 旧当前匹配还原为普通高亮
        if lastCurrentIndex >= 0, lastCurrentIndex < matches.count {
            let previous = matches[lastCurrentIndex]
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: previous)
            if matches.count <= SearchEngine.highlightCap {
                layoutManager.addTemporaryAttribute(.backgroundColor,
                                                    value: Self.matchColor,
                                                    forCharacterRange: previous)
            }
        }

        let range = matches[clamped]
        layoutManager.addTemporaryAttribute(.backgroundColor,
                                            value: Self.currentColor,
                                            forCharacterRange: range)
        lastCurrentIndex = clamped
        // 自动定位：滚动到可见 + 选中（选区变化会触发面板激活回调，同面板为 no-op）
        textView.scrollRangeToVisible(range)
        textView.setSelectedRange(range)
    }

    /// 只移除高亮属性，不动匹配缓存（供重算前清理与停用清理共用）
    private func removeHighlights(on layoutManager: NSLayoutManager, length: Int) {
        if length > 0 {
            layoutManager.removeTemporaryAttribute(.backgroundColor,
                                                   forCharacterRange: NSRange(location: 0, length: length))
        }
    }
}
