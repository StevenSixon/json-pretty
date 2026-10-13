import Foundation

/// 展示层分行结果：超长行被切成多行用于显示，逻辑原文不受影响
struct ChunkedDisplay {
    /// 展示用文本（可能含插入的换行符）
    let text: String
    /// 插入换行符在展示文本中的 UTF-16 偏移集合（用于还原）
    let breaks: IndexSet
    let isChunked: Bool
}

/// 展示分行器：规避 CoreText 对单条巨型行的 O(n²) 排版病理（实测 10MB 单行 ~40s）。
/// 超过 maxLineLength 的行按 chunkSize 切成多行显示，并记录插入位置以便精确还原。
enum DisplayChunker {
    /// 超过此行长度（字符数）触发分行
    static let maxLineLength = 65_536
    /// 展示行宽（字符数）
    static let chunkSize = 4_096

    static func process(_ text: String) -> ChunkedDisplay {
        let utf8 = [UInt8](text.utf8)
        guard utf8.count > maxLineLength else {
            // 快速路径：总量不足阈值，必然无超长行
            return ChunkedDisplay(text: text, breaks: [], isChunked: false)
        }

        var result = String()
        result.reserveCapacity(utf8.count + utf8.count / chunkSize)
        var breaks = IndexSet()
        var isChunked = false
        var displayUTF16Length = 0

        var lineStart = 0
        var index = 0

        func appendLine(_ endExclusive: Int) {
            let line = String(decoding: utf8[lineStart..<endExclusive], as: UTF8.self)
            if line.count > maxLineLength {
                isChunked = true
                var offset = line.startIndex
                while offset < line.endIndex {
                    let next = line.index(offset, offsetBy: chunkSize,
                                          limitedBy: line.endIndex) ?? line.endIndex
                    let piece = line[offset..<next]
                    result.append(contentsOf: piece)
                    displayUTF16Length += piece.utf16.count
                    offset = next
                    if offset < line.endIndex {
                        breaks.insert(displayUTF16Length)
                        result.append("\n")
                        displayUTF16Length += 1
                    }
                }
            } else {
                result.append(contentsOf: line)
                displayUTF16Length += line.utf16.count
            }
        }

        while index < utf8.count {
            if utf8[index] == 0x0A { // "\n"
                appendLine(index)
                result.append("\n")
                displayUTF16Length += 1
                lineStart = index + 1
            }
            index += 1
        }
        if lineStart < utf8.count {
            appendLine(utf8.count)
        }

        guard isChunked else {
            return ChunkedDisplay(text: text, breaks: [], isChunked: false)
        }
        return ChunkedDisplay(text: result, breaks: breaks, isChunked: true)
    }

    /// 剔除展示子串中被插入的换行符，还原逻辑文本
    /// - Parameters:
    ///   - displaySubstring: 展示文本的子串（如用户选区）
    ///   - displayOffset: 子串在展示文本中的 UTF-16 起始偏移
    ///   - breaks: process 产出的插入位置集合
    static func stripChunkBreaks(_ displaySubstring: String, displayOffset: Int, breaks: IndexSet) -> String {
        guard !breaks.isEmpty else { return displaySubstring }
        let ns = displaySubstring as NSString
        var result = String()
        result.reserveCapacity(ns.length)
        var segmentStart = 0
        let end = displayOffset + ns.length
        for position in breaks where position >= displayOffset && position < end {
            let local = position - displayOffset
            if local > segmentStart {
                result += ns.substring(with: NSRange(location: segmentStart, length: local - segmentStart))
            }
            segmentStart = local + 1 // 跳过插入的 "\n"
        }
        if segmentStart < ns.length {
            result += ns.substring(from: segmentStart)
        }
        return result
    }
}
