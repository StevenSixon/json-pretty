import AppKit
import SwiftUI

/// 只读结果文本视图：
/// - 双击复制逻辑原文（不含展示层插入的换行符）
/// - 选区复制（⌘C）剔除展示层插入的换行符，保证内容精确
final class CopyOnDoubleClickTextView: NSTextView {
    var onCopy: (() -> Void)?
    /// 逻辑原文（展示文本可能经 DisplayChunker 分行）
    var logicalText = ""
    /// 展示层插入换行符的 UTF-16 偏移集合
    var chunkBreaks = IndexSet()

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            guard !logicalText.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(logicalText, forType: .string)
            onCopy?()
            return // 双击已被“复制”语义占用，不再触发选词
        }
        super.mouseDown(with: event)
    }

    override func copy(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0, range.location + range.length <= (string as NSString).length else {
            super.copy(sender)
            return
        }
        let selected = (string as NSString).substring(with: range)
        let exact = DisplayChunker.stripChunkBreaks(selected,
                                                    displayOffset: range.location,
                                                    breaks: chunkBreaks)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exact, forType: .string)
    }
}

/// 右侧结果区：只读，双击复制全部内容。
/// 性能配置（基准实测）：不换行 + 横向滚动 + 非连续惰性布局；
/// 含超长行的结果（如压缩 JSON）经 DisplayChunker 分行显示，规避 CoreText 巨型行病理。
struct ResultView: NSViewRepresentable {
    let text: String
    var onCopy: (() -> Void)?
    /// 搜索控制器（可选；传入后支持高亮与定位）
    var search: SearchController?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = CopyOnDoubleClickTextView()
        textView.onCopy = onCopy
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                       height: CGFloat.greatestFiniteMagnitude)
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = []
        textView.delegate = context.coordinator

        context.coordinator.textView = textView
        context.coordinator.highlighter = SearchHighlighter(textView: textView)
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CopyOnDoubleClickTextView else { return }
        if textView.logicalText != text {
            let chunk = DisplayChunker.process(text)
            BenchTimer.mark("结果区：开始写入 \(chunk.text.utf8.count / 1_000_000)MB 展示文本(分行=\(chunk.isChunked))")
            context.coordinator.isRefreshing = true
            TextViewFastPath.setString(chunk.text, on: scrollView)
            context.coordinator.isRefreshing = false
            BenchTimer.mark("结果区：写入完成")
            textView.logicalText = text
            textView.chunkBreaks = chunk.breaks
        }
        if let search {
            context.coordinator.search = search
            context.coordinator.highlighter?.apply(controller: search, pane: .result)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: CopyOnDoubleClickTextView?
        var highlighter: SearchHighlighter?
        var search: SearchController?
        /// 程序化写入标记：期间的选区重置不应触发搜索面板切换
        var isRefreshing = false

        /// 结果区点击/选区变化 → 搜索作用面板切换到右栏
        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isRefreshing else { return }
            search?.setActivePane(.result)
        }
    }
}
