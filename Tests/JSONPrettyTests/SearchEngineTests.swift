import XCTest
@testable import JSONPretty

final class SearchEngineTests: XCTestCase {

    private func strings(_ text: String, matches: [NSRange]) -> [String] {
        let ns = text as NSString
        return matches.map { ns.substring(with: $0) }
    }

    func testBasicMatches() {
        let matches = SearchEngine.findMatches(in: #"{"name":"ssdf","name2":"ssdf"}"#, query: "ssdf")
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(strings(#"{"name":"ssdf","name2":"ssdf"}"#, matches: matches), ["ssdf", "ssdf"])
    }

    func testCaseInsensitive() {
        let matches = SearchEngine.findMatches(in: "JSON json Json", query: "json")
        XCTAssertEqual(matches.count, 3)
    }

    func testEmptyQueryReturnsEmpty() {
        XCTAssertTrue(SearchEngine.findMatches(in: "abc", query: "").isEmpty)
    }

    func testEmptyTextReturnsEmpty() {
        XCTAssertTrue(SearchEngine.findMatches(in: "", query: "a").isEmpty)
    }

    func testNoMatchReturnsEmpty() {
        XCTAssertTrue(SearchEngine.findMatches(in: "hello world", query: "xyz").isEmpty)
    }

    func testCollectCapRespected() {
        let text = String(repeating: "ab", count: 100_000) // 10 万个 "a"
        let matches = SearchEngine.findMatches(in: text, query: "a")
        XCTAssertEqual(matches.count, SearchEngine.collectCap)
    }

    func testLargeTextPerformance() {
        // 18MB 文本搜索耗时应可接受
        let line = #"{"id":1,"name":"item","city":"广州"}"#
        let text = (0..<150_000).map { _ in line }.joined(separator: "\n")
        let start = CFAbsoluteTimeGetCurrent()
        let matches = SearchEngine.findMatches(in: text, query: "广州")
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        print("⏱ 18MB 搜索 \(matches.count) 个匹配耗时 \(String(format: "%.3f", elapsed))s")
        XCTAssertEqual(matches.count, SearchEngine.collectCap) // 15 万匹配触及收集上限 5 万
        XCTAssertLessThan(elapsed, 2.0)
    }

    func testOverlappingQueryTerminates() {
        // 易死循环用例：查询词自身重叠（"aa" in "aaaa"）
        let matches = SearchEngine.findMatches(in: "aaaa", query: "aa")
        XCTAssertEqual(matches.count, 2) // [0,2)、[2,4)，不重叠推进
    }

    // MARK: - 模糊匹配

    func testFuzzySubsequenceMatch() {
        // "z9" 的字符按序出现在 `"zip": "981942"` 中
        let text = #"{"zip": "981942", "city": "广州"}"#
        let matches = SearchEngine.findMatches(in: text, query: "z9", fuzzy: true)
        XCTAssertEqual(matches.count, 1)
        let matched = (text as NSString).substring(with: matches[0])
        XCTAssertTrue(matched.hasPrefix("zip"), "命中区间应从 z 开始")
        XCTAssertTrue(matched.contains("9"), "命中区间应延伸到 9")
    }

    func testFuzzyNoMatchAcrossLines() {
        // 模糊匹配不跨行：字符分散在两行则不命中
        let text = "abc\ndef"
        XCTAssertTrue(SearchEngine.findMatches(in: text, query: "af", fuzzy: true).isEmpty)
        // 同一行内按序出现则命中
        XCTAssertEqual(SearchEngine.findMatches(in: "aXXf", query: "af", fuzzy: true).count, 1)
    }

    func testFuzzyCaseInsensitive() {
        let matches = SearchEngine.findMatches(in: "Hello World", query: "hw", fuzzy: true)
        XCTAssertEqual(matches.count, 1)
    }

    func testFuzzyOutOfOrderNoMatch() {
        // 字符顺序颠倒不命中
        XCTAssertTrue(SearchEngine.findMatches(in: "ba", query: "ab", fuzzy: true).isEmpty)
    }

    func testExactModeUnaffectedByFuzzyFlag() {
        let text = "aXXf"
        // 精确模式：子串不存在
        XCTAssertTrue(SearchEngine.findMatches(in: text, query: "af", fuzzy: false).isEmpty)
        // 模糊模式：子序列存在
        XCTAssertEqual(SearchEngine.findMatches(in: text, query: "af", fuzzy: true).count, 1)
    }
}
