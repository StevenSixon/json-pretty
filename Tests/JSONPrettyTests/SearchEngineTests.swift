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
}
