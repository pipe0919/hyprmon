import XCTest
@testable import HyprmonCore

final class ClaudeAPIClientTests: XCTestCase {
    func testParsesFullResponse() throws {
        let json = """
        {
          "five_hour":      { "utilization": 47.2, "resets_at": "2026-05-15T22:00:00Z" },
          "seven_day":      { "utilization": 18.5, "resets_at": "2026-05-19T00:00:00Z" },
          "seven_day_opus": { "utilization":  3.0, "resets_at": "2026-05-19T00:00:00Z" },
          "plan": "Max"
        }
        """.data(using: .utf8)!
        let usage = try ClaudeAPIClient.parse(data: json)
        XCTAssertEqual(usage.plan, "Max")
        XCTAssertEqual(usage.fiveHour?.utilization, 47.2)
        XCTAssertEqual(usage.weekly?.utilization, 18.5)
        XCTAssertEqual(usage.weeklyOpus?.utilization, 3.0)
        XCTAssertNotNil(usage.fiveHour?.resetsAt)
    }

    func testInfersMaxFromOpusWindow() throws {
        let json = """
        {
          "five_hour":      { "utilization": 10.0, "resets_at": "2026-05-15T22:00:00Z" },
          "seven_day":      { "utilization":  5.0, "resets_at": "2026-05-19T00:00:00Z" },
          "seven_day_opus": { "utilization":  1.0, "resets_at": "2026-05-19T00:00:00Z" }
        }
        """.data(using: .utf8)!
        let usage = try ClaudeAPIClient.parse(data: json)
        XCTAssertEqual(usage.plan, "Max")
    }

    func testDefaultsToProWhenNoOpus() throws {
        let json = """
        {
          "five_hour":      { "utilization": 10.0, "resets_at": "2026-05-15T22:00:00Z" },
          "seven_day":      { "utilization":  5.0, "resets_at": "2026-05-19T00:00:00Z" },
          "seven_day_opus": { "utilization":  0.0, "resets_at": "2026-05-19T00:00:00Z" }
        }
        """.data(using: .utf8)!
        let usage = try ClaudeAPIClient.parse(data: json)
        XCTAssertEqual(usage.plan, "Pro")
    }

    func testCredentialsExtractsNestedToken() {
        let raw = #"{"claudeAiOauth":{"accessToken":"sk-ant-oat01-EXAMPLE","refreshToken":"x"}}"#
        XCTAssertEqual(ClaudeCredentials.extractToken(fromJSONString: raw), "sk-ant-oat01-EXAMPLE")
    }

    func testCredentialsExtractsFlatAccessToken() {
        let raw = #"{"accessToken":"sk-ant-FLAT"}"#
        XCTAssertEqual(ClaudeCredentials.extractToken(fromJSONString: raw), "sk-ant-FLAT")
    }

    func testCredentialsReturnsNilOnGarbage() {
        XCTAssertNil(ClaudeCredentials.extractToken(fromJSONString: "not json"))
        XCTAssertNil(ClaudeCredentials.extractToken(fromJSONString: ""))
    }
}
