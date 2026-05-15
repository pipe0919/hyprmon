import XCTest
@testable import HyprmonCore

final class ConfigTests: XCTestCase {
    func testDecodeFullConfig() throws {
        let toml = """
        opacity = 0.7
        accent = "#FF0000"
        refresh_ms = 2000
        claude_refresh_ms = 60000

        [modules]
        cpu = true
        ram = false
        battery = true
        processes = true
        claude = false

        [processes]
        count = 3
        sort_by = "ram"

        [claude]
        show_5h = false
        show_weekly = true
        """
        let cfg = try Config.decode(from: TOMLParser.parse(toml))
        XCTAssertEqual(cfg.opacity, 0.7)
        XCTAssertEqual(cfg.accentHex, "#FF0000")
        XCTAssertEqual(cfg.refreshMs, 2000)
        XCTAssertEqual(cfg.claudeRefreshMs, 60_000)
        XCTAssertFalse(cfg.modules.ram)
        XCTAssertFalse(cfg.modules.claude)
        XCTAssertEqual(cfg.processes.count, 3)
        XCTAssertEqual(cfg.processes.sortBy, .ram)
        XCTAssertFalse(cfg.claude.show5h)
        XCTAssertTrue(cfg.claude.showWeekly)
    }

    func testDecodeUsesDefaultsForMissingKeys() throws {
        let cfg = try Config.decode(from: TOMLParser.parse("opacity = 0.5"))
        XCTAssertEqual(cfg.opacity, 0.5)
        XCTAssertEqual(cfg.refreshMs, 1000)
    }

    func testDecodeClaudeShowFlags() throws {
        let toml = """
        [claude]
        show_5h     = false
        show_weekly = false
        """
        let cfg = try Config.decode(from: TOMLParser.parse(toml))
        XCTAssertFalse(cfg.claude.show5h)
        XCTAssertFalse(cfg.claude.showWeekly)
    }

    func testLoadFromDiskReadsFile() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("hyprmon-test-\(UUID()).toml")
        try """
        opacity = 0.42
        """.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let cfg = try ConfigLoader.loadFromDisk(at: tmp.path)
        XCTAssertEqual(cfg.opacity, 0.42)
    }

    func testLoadFromDiskFallsBackToDefaultIfMissing() throws {
        let cfg = try ConfigLoader.loadFromDisk(at: "/nonexistent/hyprmon.toml")
        XCTAssertEqual(cfg, .default)
    }
}
