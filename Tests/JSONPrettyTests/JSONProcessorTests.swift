import XCTest
@testable import JSONPretty

final class JSONProcessorTests: XCTestCase {
    let processor = JSONProcessor()

    func testPrettyFormat() async throws {
        let input = #"{"b":2,"a":{"x":[1,2,3],"y":"hello"}}"#
        let output = try await processor.format(input, mode: .pretty)
        XCTAssertTrue(output.contains("\n"), "格式化后应包含换行")
        XCTAssertTrue(output.contains(#""hello""#))
        // 格式化结果必须是合法 JSON 且与原数据等价
        let original = try JSONSerialization.jsonObject(with: Data(input.utf8)) as? [String: Any]
        let formatted = try JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any]
        XCTAssertEqual(original?["b"] as? Int, formatted?["b"] as? Int)
    }

    func testCompactFormat() async throws {
        let input = """
        {
            "a": 1,
            "b": [1, 2, 3]
        }
        """
        let output = try await processor.format(input, mode: .compact)
        XCTAssertFalse(output.contains("\n"), "压缩后不应包含换行")
        XCTAssertFalse(output.contains(" "), "压缩后不应包含空格")
        XCTAssertEqual(output, #"{"a":1,"b":[1,2,3]}"#)
    }

    func testInvalidJSONReportsLocation() async {
        let input = "{\n  \"a\": 1,\n  bad\n}"
        do {
            _ = try await processor.format(input, mode: .pretty)
            XCTFail("非法 JSON 应抛错")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("JSON 解析失败"))
        }
    }

    func testEmptyInput() async throws {
        let empty = try await processor.format("", mode: .pretty)
        let whitespace = try await processor.format("   \n ", mode: .pretty)
        XCTAssertEqual(empty, "")
        XCTAssertEqual(whitespace, "")
    }

    func testUnicodeAndSlashes() async throws {
        let input = #"{"url":"https:\/\/a.com\/b","emoji":"🚀","zh":"中文"}"#
        let output = try await processor.format(input, mode: .compact)
        XCTAssertTrue(output.contains("🚀"))
        XCTAssertTrue(output.contains("中文"))
        XCTAssertTrue(output.contains("https://a.com/b"), "不应转义斜杠")
    }

    func testLargeJSONPerformance() async throws {
        // 构造 ~2MB+ JSON：2 万个对象数组
        var items: [String] = []
        items.reserveCapacity(20_000)
        for i in 0..<20_000 {
            items.append(#"{"id":\#(i),"name":"item-\#(i)","tags":["a","b","c"],"nested":{"x":\#(i),"y":"value-\#(i)"}}"#)
        }
        let input = "[" + items.joined(separator: ",") + "]"
        XCTAssertGreaterThan(input.utf8.count, 1_000_000)

        let start = CFAbsoluteTimeGetCurrent()
        let pretty = try await processor.format(input, mode: .pretty)
        let prettyTime = CFAbsoluteTimeGetCurrent() - start

        let compactStart = CFAbsoluteTimeGetCurrent()
        let compact = try await processor.format(pretty, mode: .compact)
        let compactTime = CFAbsoluteTimeGetCurrent() - compactStart

        print("⏱ pretty: \(String(format: "%.3f", prettyTime))s, compact: \(String(format: "%.3f", compactTime))s, input: \(input.utf8.count / 1_000_000)MB")
        XCTAssertLessThan(prettyTime, 3.0, "10MB 级 JSON 格式化应在 3 秒内完成")
        XCTAssertLessThan(compactTime, 3.0)
        XCTAssertFalse(compact.isEmpty)
    }
}
