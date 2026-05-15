import Foundation

public struct Config: Equatable, Sendable {
    public enum ProcessSort: String, Sendable {
        case cpu, ram, energy
    }

    public struct Modules: Equatable, Sendable {
        public var cpu = true
        public var ram = true
        public var battery = true
        public var processes = true
        public var claude = true
    }

    public struct ProcessOpts: Equatable, Sendable {
        public var count: Int = 5
        public var sortBy: ProcessSort = .cpu
    }

    public struct ClaudeOpts: Equatable, Sendable {
        public var show5h = true
        public var showWeekly = true
    }

    public var opacity: Double = 0.85
    public var accentHex: String = "#7AA2F7"
    public var refreshMs: Int = 1000
    public var claudeRefreshMs: Int = 60_000
    public var modules = Modules()
    public var processes = ProcessOpts()
    public var claude = ClaudeOpts()

    public static let `default` = Config()

    public init() {}
}

public extension Config {
    static func decode(from dict: [String: Any]) throws -> Config {
        var c = Config()

        if let v = dict["opacity"] as? Double { c.opacity = v }
        if let v = dict["opacity"] as? Int    { c.opacity = Double(v) }
        if let v = dict["accent"]  as? String { c.accentHex = v }
        if let v = dict["refresh_ms"]        as? Int { c.refreshMs = v }
        if let v = dict["claude_refresh_ms"] as? Int { c.claudeRefreshMs = v }

        if let m = dict["modules"] as? [String: Any] {
            if let v = m["cpu"]       as? Bool { c.modules.cpu = v }
            if let v = m["ram"]       as? Bool { c.modules.ram = v }
            if let v = m["battery"]   as? Bool { c.modules.battery = v }
            if let v = m["processes"] as? Bool { c.modules.processes = v }
            if let v = m["claude"]    as? Bool { c.modules.claude = v }
        }

        if let p = dict["processes"] as? [String: Any] {
            if let v = p["count"] as? Int { c.processes.count = v }
            if let s = p["sort_by"] as? String, let v = ProcessSort(rawValue: s) { c.processes.sortBy = v }
        }

        if let cl = dict["claude"] as? [String: Any] {
            if let v = cl["show_5h"]     as? Bool { c.claude.show5h = v }
            if let v = cl["show_weekly"] as? Bool { c.claude.showWeekly = v }
        }
        return c
    }
}
