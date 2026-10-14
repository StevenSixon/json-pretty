import AppKit
import SwiftUI

/// 大文本写入阈值：超过则走“摘除-设置-放回”快路径（实测 38s → 0.3s）
enum TextViewFastPath {
    static let threshold = 1_000_000

    /// 在窗口中显示的 NSTextView 直接设置大字符串会触发同步全量排版（病理路径）。
    /// 先摘除 documentView 离屏设置再放回，布局保持惰性。
    static func setString(_ text: String, on scrollView: NSScrollView) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if text.utf8.count > threshold {
            scrollView.documentView = nil
            textView.string = text
            scrollView.documentView = textView
        } else {
            textView.string = text
        }
    }
}

/// 编辑器文本视图：
/// - 锁定态（含超长行的大文件）：粘贴 = 整体替换内容
/// - 非锁定态大粘贴：整体重组文本走分行管线；不能用 insertText（会触发
///   scrollRangeToVisible → 强制全量排版，实测 10MB 卡 39s）
final class EditorTextView: NSTextView {
    var onReplaceAll: ((String) -> Void)?
    /// 大粘贴回调：参数为剪贴板内容与当前选区
    var onPasteLarge: ((String, NSRange) -> Void)?
    var isLocked = false

    override func paste(_ sender: Any?) {
        guard let content = NSPasteboard.general.string(forType: .string) else {
            super.paste(sender)
            return
        }
        if isLocked {
            onReplaceAll?(content)
            return
        }
        if content.utf8.count > TextViewFastPath.threshold {
            BenchTimer.mark("编辑器：大粘贴开始（\(content.utf8.count / 1_000_000)MB）")
            onPasteLarge?(content, selectedRange())
            return
        }
        super.paste(sender)
    }
}

/// 左侧输入编辑器：NSTextView 包装，大文本下远优于 SwiftUI TextEditor。
///
/// 大文件策略（基准实测驱动）：
/// - CoreText 对单条巨型行的排版是 O(n²) 病理（10MB 单行 ~40s，TextKit 1/2 同病）
/// - 因此含超长行的内容进入“锁定展示模式”：按 4096 字符分行显示、只读、粘贴整体替换
/// - 逻辑原文始终保存在模型层，分行只是显示层处理
struct EditorView: NSViewRepresentable {
    @Binding var text: String
    /// 锁定状态变化回调（用于 UI 展示提示）
    var onLockChange: ((Bool) -> Void)?
    /// 搜索控制器（可选；传入后支持高亮与定位）
    var search: SearchController?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = EditorTextView()
        textView.delegate = context.coordinator
        textView.onReplaceAll = { [weak coordinator = context.coordinator] content in
            coordinator?.replaceAll(with: content)
        }
        textView.onPasteLarge = { [weak coordinator = context.coordinator] content, selection in
            coordinator?.pasteLarge(content, selection: selection)
        }
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        // 关闭一切自动改写，保证 JSON 原文不被“智能”标点破坏
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        // 性能配置（基准实测）：非连续惰性布局 + 不换行 + 横向滚动 + maxSize 不钳制
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                       height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = []

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.highlighter = SearchHighlighter(textView: textView)
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // 外部变更（打开文件/历史恢复/锁定态粘贴替换）时同步；
        // 用户输入时 delegate 已回写 binding，currentLogical 一致则不重设
        context.coordinator.syncLogical(text)
        if let search {
            context.coordinator.highlighter?.apply(controller: search, pane: .editor)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        weak var textView: EditorTextView?
        weak var scrollView: NSScrollView?
        var highlighter: SearchHighlighter?
        /// 当前展示内容对应的逻辑原文
        private(set) var currentLogical = ""
        /// 分行/回填展示文本期间屏蔽 textDidChange，避免把展示文本误写回模型
        private var isRefreshing = false
        private var isLocked = false

        init(_ parent: EditorView) { self.parent = parent }

        /// 以外部逻辑文本为准刷新展示
        func syncLogical(_ logical: String) {
            guard logical != currentLogical else { return }
            currentLogical = logical
            refreshDisplay()
        }

        /// 锁定态下整体替换内容（粘贴触发）
        func replaceAll(with content: String) {
            currentLogical = content
            parent.text = content
            refreshDisplay()
        }

        /// 大粘贴：在选区位置插入剪贴板内容，整体重组后走分行管线。
        /// 不走 insertText（会 scrollRangeToVisible 强制排版）；大粘贴不支持撤销。
        func pasteLarge(_ content: String, selection: NSRange) {
            guard let textView else { return }
            let current = textView.string as NSString
            let newLogical = current.replacingCharacters(in: selection, with: content)
            currentLogical = newLogical
            parent.text = newLogical
            refreshDisplay()
            // 光标定位到插入内容之后（分行后展示坐标有偏移，取钳制值即可）
            let displayLength = (textView.string as NSString).length
            let target = selection.location + (content as NSString).length
            textView.setSelectedRange(NSRange(location: min(target, displayLength), length: 0))
            BenchTimer.mark("编辑器：大粘贴完成")
        }

        func textDidChange(_ notification: Notification) {
            guard !isRefreshing, let textView = notification.object as? NSTextView else { return }
            let raw = textView.string
            currentLogical = raw
            parent.text = raw
            // 用户持续输入/粘贴可能使内容越过阈值，需重新评估分行
            if raw.utf8.count > DisplayChunker.maxLineLength {
                refreshDisplay()
            }
        }

        /// 编辑器获得焦点/选区变化 → 搜索作用面板切换到左栏。
        /// 程序化写入（isRefreshing）引发的选区重置不算用户焦点行为。
        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isRefreshing else { return }
            parent.search?.setActivePane(.editor)
        }

        private func refreshDisplay() {
            guard let textView, let scrollView else { return }
            let chunk = DisplayChunker.process(currentLogical)
            guard chunk.text != textView.string else { return }

            isRefreshing = true
            BenchTimer.mark("编辑器：开始写入 \(chunk.text.utf8.count / 1_000_000)MB 展示文本(分行=\(chunk.isChunked))")
            TextViewFastPath.setString(chunk.text, on: scrollView)
            BenchTimer.mark("编辑器：写入完成")
            isRefreshing = false

            if chunk.isChunked != isLocked {
                isLocked = chunk.isChunked
                textView.isLocked = chunk.isChunked
                textView.isEditable = !chunk.isChunked
                parent.onLockChange?(chunk.isChunked)
            }
        }
    }
}
