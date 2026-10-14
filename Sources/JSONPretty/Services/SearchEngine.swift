import Foundation

/// 纯文本搜索：不区分大小写，返回所有匹配的 UTF-16 区间
enum SearchEngine {
    /// 匹配收集上限（防止极端文档产生无限匹配列表）
    static let collectCap = 50_000
    /// 高亮上限：超过则只导航不高亮（大量临时属性会拖慢排版）
    static let highlightCap = 5_000

    static func findMatches(in text: String, query: String, cap: Int = collectCap) -> [NSRange] {
        guard !query.isEmpty else { return [] }
        let ns = text as NSString
        guard ns.length > 0 else { return [] }

        var ranges: [NSRange] = []
        ranges.reserveCapacity(256)
        var searchRange = NSRange(location: 0, length: ns.length)
        while ranges.count < cap {
            let found = ns.range(of: query, options: [.caseInsensitive], range: searchRange)
            guard found.location != NSNotFound else { break }
            ranges.append(found)
            let next = found.location + max(found.length, 1)
            guard next < ns.length else { break }
            searchRange = NSRange(location: next, length: ns.length - next)
        }
        return ranges
    }
}
