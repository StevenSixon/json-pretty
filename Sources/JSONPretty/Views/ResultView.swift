import AppKit
import SwiftUI

/// 双击时复制全文的只读文本视图
private final class CopyOnDoubleClickTextView: NSTextView {
    var onCopy: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            let content = string
            guard !content.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)
            onCopy?()
            return // 双击已被“复制”语义占用，不再触发选词
        }
        super.mouseDown(with: event)
    }
}

/// 右侧结果区：只读，双击复制全部内容。
/// 性能配置（基准实测）：不换行 + 横向滚动 + 非连续惰性布局。
/// 单行 10MB 文本一次性字形生成 ~1s；多行 18MB 首屏 ~0.03s。
/// （换行模式下，单段落折成数万行 line fragment，排版需 ~20s，禁用。）
struct ResultView: NSViewRepresentable {
    let text: String
    var onCopy: (() -> Void)?

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
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
}
