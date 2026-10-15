import Foundation

/// 纯文本搜索：不区分大小写，返回所有匹配的 UTF-16 区间
enum SearchEngine {
    /// 匹配收集上限（防止极端文档产生无限匹配列表）
    static let collectCap = 50_000
    /// 高亮上限：超过则只导航 + 高亮当前匹配（海量临时属性会拖慢排版）
    static let highlightCap = 20_000

    /// 精确匹配：子串查找
    /// 模糊匹配：查询词字符按序出现在同一行内即命中，返回行内最小跨度
    static func findMatches(in text: String, query: String, fuzzy: Bool = false,
                            cap: Int = collectCap) -> [NSRange] {
        guard !query.isEmpty else { return [] }
        return fuzzy ? findFuzzyMatches(in: text, query: query, cap: cap)
                     : findExactMatches(in: text, query: query, cap: cap)
    }

    static func findExactMatches(in text: String, query: String, cap: Int = collectCap) -> [NSRange] {
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

    /// 模糊匹配：对每行做子序列匹配（如 "z9" 命中 `"zip": "981942"`），命中区间为行内首末字符跨度
    static func findFuzzyMatches(in text: String, query: String, cap: Int = collectCap) -> [NSRange] {
        let queryChars = Array(query.lowercased())
        guard !queryChars.isEmpty else { return [] }

        var ranges: [NSRange] = []
        var lineStartUTF16 = 0
        let ns = text as NSString

        ns.enumerateLines { line, _ in
            guard ranges.count < cap else { return }
            let lineNS = line as NSString
            let lineLength = lineNS.length

            // 单指针扫描：行内按序消费查询字符
            var queryIndex = 0
            var firstIndex = -1
            var lastIndex = -1
            var position = 0
            let lineLower = line.lowercased()

            for char in lineLower {
                if char == queryChars[queryIndex] {
                    if firstIndex < 0 { firstIndex = position }
                    lastIndex = position
                    queryIndex += 1
                    if queryIndex == queryChars.count { break }
                }
                position += (char as Character).utf16.count
            }

            if queryIndex == queryChars.count {
                let location = lineStartUTF16 + firstIndex
                ranges.append(NSRange(location: location, length: lastIndex - firstIndex + 1))
            }
            lineStartUTF16 += lineLength + 1 // + 1 为换行符
        }
        return ranges
    }
}
