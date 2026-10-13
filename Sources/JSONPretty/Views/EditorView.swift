import AppKit
import SwiftUI

/// 左侧输入编辑器：NSTextView 包装，大文本下远优于 SwiftUI TextEditor。
struct EditorView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollablePlainDocumentContentTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        // 性能配置（基准实测，10MB 文本）：
        // - 非连续惰性布局：只排版可视区域，多行文本首屏 ~0.03s
        // - 不换行 + 横向滚动：单行 10MB 压缩 JSON 一次性字形生成 ~1s；
        //   若换行，单段落折成数万行 line fragment，排版需 ~20s（实测）
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                       height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = true
        scrollView.hasHorizontalScroller = true
        // 关闭一切自动改写，保证 JSON 原文不被“智能”标点破坏
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // 外部变更（如打开文件）时同步；用户输入时 delegate 已回写 binding，无需重设
        if textView.string != text {
            let selection = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selection
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        init(_ parent: EditorView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
