import XCTest
@testable import HyprmonCore

final class TOMLParserTests: XCTestCase {
    func testParsesStringIntFloatBool() throws {
        let toml = """
        corner = "top-right"
        margin = 12
        opacity = 0.85
        enabled = true
        """
        let v = try TOMLParser.parse(toml)
        XCTAssertEqual(v["corner"] as? String, "top-right")
        XCTAssertEqual(v["margin"] as? Int, 12)
        XCTAssertEqual(v["opacity"] as? Double, 0.85)
        XCTAssertEqual(v["enabled"] as? Bool, true)
    }

    func testIgnoresCommentsAndBlankLines() throws {
        let toml = """
        # this is a comment

        corner = "top-right"   # trailing comment
        """
        let v = try TOMLParser.parse(toml)
        XCTAssertEqual(v["corner"] as? String, "top-right")
    }

    func testParsesTables() throws {
        let toml = """
        opacity = 0.5

        [modules]
        cpu = true
        ram = false

        [claude]
        plan = "max20"
        """
        let v = try TOMLParser.parse(toml)
        XCTAssertEqual(v["opacity"] as? Double, 0.5)
        let modules = v["modules"] as? [String: Any]
        XCTAssertEqual(modules?["cpu"] as? Bool, true)
        XCTAssertEqual(modules?["ram"] as? Bool, false)
        let claude = v["claude"] as? [String: Any]
        XCTAssertEqual(claude?["plan"] as? String, "max20")
    }

    func testParsesNestedTable() throws {
        let toml = """
        [claude.limits]
        window_5h_tokens = 880000
        """
        let v = try TOMLParser.parse(toml)
        let claude = v["claude"] as? [String: Any]
        let limits = claude?["limits"] as? [String: Any]
        XCTAssertEqual(limits?["window_5h_tokens"] as? Int, 880_000)
    }

    func testThrowsOnInvalidSyntax() {
        XCTAssertThrowsError(try TOMLParser.parse("this is not toml"))
    }
}
