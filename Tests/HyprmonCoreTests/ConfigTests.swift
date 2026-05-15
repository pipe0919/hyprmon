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
        plan = "max5"
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
        XCTAssertEqual(cfg.claude.plan, .max5)
        XCTAssertFalse(cfg.claude.show5h)
        XCTAssertTrue(cfg.claude.showWeekly)
    }

    func testDecodeUsesDefaultsForMissingKeys() throws {
        let cfg = try Config.decode(from: TOMLParser.parse("opacity = 0.5"))
        XCTAssertEqual(cfg.opacity, 0.5)
        XCTAssertEqual(cfg.refreshMs, 1000)
    }

    func testDecodeCustomPlanLimits() throws {
        let toml = """
        [claude]
        plan = "custom"

        [claude.limits]
        window_5h_tokens = 500000
        window_weekly_tokens = 4000000
        """
        let cfg = try Config.decode(from: TOMLParser.parse(toml))
        XCTAssertEqual(cfg.claude.plan, .custom)
        XCTAssertEqual(cfg.claude.window5hTokens, 500_000)
        XCTAssertEqual(cfg.claude.windowWeeklyTokens, 4_000_000)
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
