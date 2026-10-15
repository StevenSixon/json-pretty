import AppKit

/// 搜索高亮器：供编辑器/结果区两个面板的 Coordinator 复用。
/// 搜索异步执行（200ms 防抖 + 后台计算），高亮与滚动定位在主线程应用。
@MainActor
final class SearchHighlighter {
    /// 普通匹配：浅黄；当前匹配：深一档的琥珀黄以便区分
    private static let matchColor = NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.40, alpha: 0.55)
    private static let currentColor = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.15, alpha: 0.85)

    private static let debounce: Duration = .milliseconds(200)

    private weak var textView: NSTextView?
    private var matches: [NSRange] = []
    private var lastQuery: String?
    private var lastString: String?
    private var lastFuzzy = false
    private var lastLength = 0
    private var lastCurrentIndex = -1
    /// 搜索任务代际：丢弃过期结果
    private var generation = 0
    private var searchTask: Task<Void, Never>?

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
                searchTask?.cancel()
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

        // 查询词 / 内容 / 匹配模式变化 → 防抖后后台重算
        if controller.query != lastQuery || string != lastString || controller.fuzzy != lastFuzzy {
            removeHighlights(on: layoutManager, length: max(lastLength, (string as NSString).length))
            lastQuery = controller.query
            lastString = string
            lastFuzzy = controller.fuzzy
            lastLength = (string as NSString).length
            matches = []
            lastCurrentIndex = -1

            generation += 1
            let gen = generation
            let query = controller.query
            let fuzzy = controller.fuzzy
            // 不可变快照：避免后台读取与 textStorage 主线程写竞争
            let snapshot = String((string as NSString).copy() as! NSString)

            searchTask?.cancel()
            searchTask = Task { [weak self] in
                try? await Task.sleep(for: Self.debounce)
                guard !Task.isCancelled else { return }
                let found = await Task.detached(priority: .userInitiated) {
                    SearchEngine.findMatches(in: snapshot, query: query, fuzzy: fuzzy)
                }.value
                guard let self, !Task.isCancelled, gen == self.generation else { return }
                guard controller.isVisible, controller.query == query else { return }
                self.matches = found
                controller.updateMatchCount(found.count, for: pane)
                self.applyHighlights()
                if let textView = self.textView, let lm = textView.layoutManager {
                    self.showCurrent(controller.currentIndex, on: textView, layoutManager: lm)
                }
            }
            return
        }

        showCurrent(controller.currentIndex, on: textView, layoutManager: layoutManager)
    }

    private func applyHighlights() {
        guard let textView, let layoutManager = textView.layoutManager else { return }
        guard matches.count <= SearchEngine.highlightCap else { return } // 超限只导航 + 当前高亮
        for range in matches {
            layoutManager.addTemporaryAttribute(.backgroundColor,
                                                value: Self.matchColor,
                                                forCharacterRange: range)
        }
        // 批量刷新一次可视区，而不是每次 add 都各自触发
        textView.setNeedsDisplay(textView.visibleRect)
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

    /// 只移除高亮属性，不动匹配缓存
    private func removeHighlights(on layoutManager: NSLayoutManager, length: Int) {
        if length > 0 {
            layoutManager.removeTemporaryAttribute(.backgroundColor,
                                                   forCharacterRange: NSRange(location: 0, length: length))
        }
    }
}
