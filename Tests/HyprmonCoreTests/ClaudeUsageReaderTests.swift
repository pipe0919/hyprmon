import XCTest
@testable import HyprmonCore

final class ClaudeUsageReaderTests: XCTestCase {
    func makeFixtureDir(events: [(Date, Int, Int, Int, Int)]) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("claude-fixture-\(UUID())")
        let projectDir = tmp.appendingPathComponent("projects/-Users-test")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let file = projectDir.appendingPathComponent("session.jsonl")
        var lines: [String] = []
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for (ts, inTok, outTok, ccTok, crTok) in events {
            let obj: [String: Any] = [
                "timestamp": iso.string(from: ts),
                "message": [
                    "usage": [
                        "input_tokens": inTok,
                        "output_tokens": outTok,
                        "cache_creation_input_tokens": ccTok,
                        "cache_read_input_tokens": crTok,
                    ]
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: obj, options: [])
            lines.append(String(data: data, encoding: .utf8)!)
        }
        try lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        return tmp
    }

    func testSumsAcrossWindow() throws {
        let now = Date()
        let root = try makeFixtureDir(events: [
            (now.addingTimeInterval(-60),     100, 200, 0, 0),
            (now.addingTimeInterval(-3600),    50,  50, 100, 0),
            (now.addingTimeInterval(-3600*8),  10,  10,   0, 0),
        ])
        defer { try? FileManager.default.removeItem(at: root) }
        let reader = ClaudeUsageReader(root: root)
        let snap = reader.read(asOf: now)
        XCTAssertEqual(snap.window5h.totalTokens(asOf: now), 500)
        XCTAssertEqual(snap.weekly.totalTokens(asOf: now), 520)
    }

    func testIgnoresLinesWithoutUsage() throws {
        let now = Date()
        let root = try makeFixtureDir(events: [
            (now.addingTimeInterval(-60), 100, 100, 0, 0),
        ])
        let file = root.appendingPathComponent("projects/-Users-test/session.jsonl")
        var contents = try String(contentsOf: file, encoding: .utf8)
        contents += "\n" + #"{"timestamp":"2026-05-15T10:00:00Z","other":"data"}"#
        try contents.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }
        let reader = ClaudeUsageReader(root: root)
        let snap = reader.read(asOf: now)
        XCTAssertEqual(snap.window5h.totalTokens(asOf: now), 200)
    }
}
