# hyprmon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `hyprmon` — a Hyprland-style macOS widget that shows CPU/RAM/battery/top-5 processes/Claude usage on a desktop-level floating panel — and publish it as an open-source project installable via Homebrew.

**Architecture:** A Swift app built with Swift Package Manager (no Xcode) that produces a `.app` bundle via `build.sh`. A single non-activating `NSPanel` at `NSWindow.Level.desktop` renders a SwiftUI view tree driven by `@Observable` samplers. Configuration lives in `~/.config/hyprmon/config.toml` with FSEvents-driven live reload. Distribution is via a Homebrew tap (`pipe0919/homebrew-tap`) populated automatically from GitHub Actions on every `v*` tag.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (`NSPanel`, `NSVisualEffectView`), IOKit (`IOPowerSources`), Darwin (`host_processor_info`, `host_statistics64`, `proc_listpids`, `proc_pid_taskinfo`), CoreServices (`FSEventStream`), Swift Package Manager, GitHub Actions, Homebrew.

**Note on stack vs. spec:** The spec mentioned "swiftc directo, sin Xcode ni SwiftPM". After planning, we use SwiftPM (still no Xcode — it's CLI via `swift build`/`swift test`) because the testing story with naked `swiftc` is painful. `build.sh` wraps `swift build` and produces the `.app` bundle. This stays true to the spec's spirit ("no Xcode") while giving us `swift test` for free.

---

## File Structure

Created in this plan:

```
hyprmon/
├── Package.swift                                  # SwiftPM manifest
├── build.sh                                       # Wraps swift build + makes .app
├── Makefile                                       # install / uninstall conveniences
├── README.md
├── CONTRIBUTING.md
├── LICENSE                                        # Apache 2.0
├── CHANGELOG.md
├── .gitignore                                     # (already exists)
├── examples/config.toml
├── Resources/
│   ├── Info.plist
│   └── AppIcon.iconset/                           # placeholder icons
├── Formula/hyprmon.rb                             # template; CI updates url+sha
├── .github/workflows/ci.yml
├── .github/workflows/release.yml
├── Sources/
│   ├── HyprmonCore/                               # library (testable logic)
│   │   ├── Theme.swift
│   │   ├── Config/
│   │   │   ├── Config.swift
│   │   │   ├── TOMLParser.swift
│   │   │   └── ConfigLoader.swift
│   │   ├── Sampling/
│   │   │   ├── CPUSampler.swift
│   │   │   ├── MemorySampler.swift
│   │   │   ├── BatterySampler.swift
│   │   │   ├── ProcessSampler.swift
│   │   │   └── SystemSampler.swift
│   │   └── Claude/
│   │       ├── PlanLimits.swift
│   │       ├── RollingWindow.swift
│   │       └── ClaudeUsageReader.swift
│   └── hyprmon/                                   # executable target
│       ├── main.swift                             # entry, CLI flag parsing
│       ├── App/
│       │   ├── DesktopPanel.swift
│       │   └── LaunchAgent.swift
│       └── Views/
│           ├── ContentView.swift
│           ├── SectionHeader.swift
│           ├── MetricBar.swift
│           ├── BatteryRow.swift
│           ├── ProcessTable.swift
│           └── ClaudeQuotaView.swift
└── Tests/
    └── HyprmonCoreTests/
        ├── CPUSamplerTests.swift
        ├── MemorySamplerTests.swift
        ├── ProcessSamplerTests.swift
        ├── ClaudeUsageReaderTests.swift
        ├── RollingWindowTests.swift
        └── TOMLParserTests.swift
```

Files that change together live together (e.g. all sampling logic in `Sampling/`). The library/executable split lets us unit-test pure logic without bringing in `@main` or AppKit dependencies.

---

## Phase 0 — Repo Bootstrap

### Task 1: Add LICENSE (Apache 2.0)

**Files:**
- Create: `LICENSE`

- [ ] **Step 1: Create the file with the standard Apache 2.0 text**

Write `LICENSE` containing the full Apache License 2.0 text from `https://www.apache.org/licenses/LICENSE-2.0.txt`, with the copyright owner block at the bottom replaced by:

```
   Copyright 2026 Felipe (@pipe0919)
```

(The full Apache 2.0 license body is ~11 KB — fetch it verbatim from the canonical source.)

- [ ] **Step 2: Commit**

```bash
cd ~/Desktop/hyprmon
git add LICENSE
git commit -m "chore: add Apache 2.0 LICENSE"
```

### Task 2: Add CHANGELOG.md and CONTRIBUTING.md placeholders

**Files:**
- Create: `CHANGELOG.md`
- Create: `CONTRIBUTING.md`

- [ ] **Step 1: Write `CHANGELOG.md`**

```markdown
# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial design spec and implementation scaffold.
```

- [ ] **Step 2: Write `CONTRIBUTING.md`**

```markdown
# Contributing to hyprmon

Thanks for your interest! hyprmon is small and focused on doing one thing well: showing system + Claude usage in a tasteful desktop widget.

## Dev setup

Requirements: macOS 13+, Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/pipe0919/hyprmon
cd hyprmon
swift test            # run unit tests
./build.sh            # build Hyprmon.app into ./build/
open ./build/Hyprmon.app
```

## Style

- Swift 5.9+ idioms; prefer `@Observable` over `ObservableObject` where possible.
- Pure logic goes in `Sources/HyprmonCore/`. View / AppKit code in `Sources/hyprmon/`.
- All new logic in `HyprmonCore` needs unit tests.

## Scope

Out of scope for v1.x:
- GPU / network / disk metrics
- Notifications / alerts
- Multiple themes
- A native Preferences window (TOML only)

If you want one of these, open an issue first so we can discuss.
```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md CONTRIBUTING.md
git commit -m "chore: add CHANGELOG and CONTRIBUTING"
```

### Task 3: Initialize Swift Package

**Files:**
- Create: `Package.swift`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "hyprmon",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "hyprmon", targets: ["hyprmon"]),
        .library(name: "HyprmonCore", targets: ["HyprmonCore"]),
    ],
    targets: [
        .target(
            name: "HyprmonCore",
            path: "Sources/HyprmonCore"
        ),
        .executableTarget(
            name: "hyprmon",
            dependencies: ["HyprmonCore"],
            path: "Sources/hyprmon"
        ),
        .testTarget(
            name: "HyprmonCoreTests",
            dependencies: ["HyprmonCore"],
            path: "Tests/HyprmonCoreTests"
        ),
    ]
)
```

- [ ] **Step 2: Create empty source dirs so swift can find targets**

```bash
mkdir -p Sources/HyprmonCore Sources/hyprmon Tests/HyprmonCoreTests
touch Sources/HyprmonCore/.keep Sources/hyprmon/.keep Tests/HyprmonCoreTests/.keep
```

- [ ] **Step 3: Verify package resolves**

```bash
swift package describe --type json | head -5
```

Expected: JSON output starting with `{`.

- [ ] **Step 4: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "chore: bootstrap Swift Package Manager structure"
```

---

## Phase 1 — Theme

### Task 4: Theme tokens

**Files:**
- Create: `Sources/HyprmonCore/Theme.swift`

- [ ] **Step 1: Write theme tokens**

```swift
import SwiftUI

public struct Theme: Sendable {
    public var accent: Color
    public var opacity: Double

    public static let `default` = Theme(accent: Color(hex: 0x7AA2F7), opacity: 0.85)

    public var fgPrimary: Color { .white.opacity(0.92) }
    public var fgMuted:   Color { .white.opacity(0.55) }
    public var surface:   Color { .white.opacity(0.04) }
    public var trackBg:   Color { .white.opacity(0.08) }
    public var ok:        Color { Color(hex: 0x9ECE6A) }
    public var warn:      Color { Color(hex: 0xE0AF68) }
    public var danger:    Color { Color(hex: 0xF7768E) }

    public init(accent: Color, opacity: Double) {
        self.accent = accent
        self.opacity = opacity
    }

    public func heatColor(for value: Double) -> Color {
        switch value {
        case ..<0.5:  return ok
        case ..<0.8:  return warn
        default:      return danger
        }
    }
}

public extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(hex: v)
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
swift build --target HyprmonCore
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/HyprmonCore/Theme.swift
git commit -m "feat(theme): add semantic theme tokens with heat-map helper"
```

---

## Phase 2 — Configuration

### Task 5: Define Config struct with defaults

**Files:**
- Create: `Sources/HyprmonCore/Config/Config.swift`

- [ ] **Step 1: Write the config struct**

```swift
import Foundation

public struct Config: Equatable, Sendable {
    public enum Corner: String, Sendable {
        case topRight    = "top-right"
        case topLeft     = "top-left"
        case bottomRight = "bottom-right"
        case bottomLeft  = "bottom-left"
    }

    public enum ProcessSort: String, Sendable {
        case cpu, ram
    }

    public enum Plan: String, Sendable {
        case pro, max5, max20, custom
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
        public var plan: Plan = .max20
        public var show5h = true
        public var showWeekly = true
        public var window5hTokens: Int? = nil      // override when plan == .custom
        public var windowWeeklyTokens: Int? = nil
    }

    public var corner: Corner = .topRight
    public var margin: Int = 12
    public var opacity: Double = 0.85
    public var accentHex: String = "#7AA2F7"
    public var refreshMs: Int = 1000
    public var claudeRefreshMs: Int = 30_000
    public var modules = Modules()
    public var processes = ProcessOpts()
    public var claude = ClaudeOpts()

    public static let `default` = Config()

    public init() {}
}
```

- [ ] **Step 2: Verify it compiles**

```bash
swift build --target HyprmonCore
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/HyprmonCore/Config/Config.swift
git commit -m "feat(config): add Config struct with defaults"
```

### Task 6: Minimal TOML parser — failing tests

**Files:**
- Create: `Tests/HyprmonCoreTests/TOMLParserTests.swift`

- [ ] **Step 1: Write tests for the parser**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter TOMLParserTests
```

Expected: build error — `TOMLParser` is not defined.

### Task 7: Implement minimal TOML parser

**Files:**
- Create: `Sources/HyprmonCore/Config/TOMLParser.swift`

- [ ] **Step 1: Write the parser**

```swift
import Foundation

public enum TOMLError: Error, CustomStringConvertible {
    case syntax(line: Int, message: String)
    public var description: String {
        switch self {
        case .syntax(let line, let msg): return "TOML syntax error on line \(line): \(msg)"
        }
    }
}

/// Minimal TOML parser supporting strings, ints, floats, bools, tables, nested tables.
/// Does NOT support: arrays, inline tables, multiline strings, datetimes.
public enum TOMLParser {
    public static func parse(_ source: String) throws -> [String: Any] {
        var root: [String: Any] = [:]
        var currentPath: [String] = []

        for (idx, rawLine) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineNo = idx + 1
            let line = stripComment(String(rawLine)).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                let inner = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                guard !inner.isEmpty else {
                    throw TOMLError.syntax(line: lineNo, message: "empty table header")
                }
                currentPath = inner.split(separator: ".").map { $0.trimmingCharacters(in: .whitespaces) }
                ensurePath(currentPath, in: &root)
                continue
            }

            guard let eq = line.firstIndex(of: "=") else {
                throw TOMLError.syntax(line: lineNo, message: "expected '=' or table header")
            }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            let raw = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else {
                throw TOMLError.syntax(line: lineNo, message: "empty key")
            }
            let value = try parseValue(String(raw), lineNo: lineNo)
            setValue(value, at: currentPath + [key], in: &root)
        }
        return root
    }

    // MARK: - Helpers

    private static func stripComment(_ line: String) -> String {
        // Strip everything after a '#' that's not inside a double-quoted string.
        var inString = false
        var out = ""
        for ch in line {
            if ch == "\"" { inString.toggle() }
            if ch == "#" && !inString { break }
            out.append(ch)
        }
        return out
    }

    private static func parseValue(_ raw: String, lineNo: Int) throws -> Any {
        if raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 {
            return String(raw.dropFirst().dropLast())
        }
        if raw == "true"  { return true }
        if raw == "false" { return false }
        if let i = Int(raw)    { return i }
        if let d = Double(raw) { return d }
        throw TOMLError.syntax(line: lineNo, message: "cannot parse value: \(raw)")
    }

    private static func ensurePath(_ path: [String], in dict: inout [String: Any]) {
        guard let head = path.first else { return }
        var sub = dict[head] as? [String: Any] ?? [:]
        if path.count == 1 {
            dict[head] = sub
        } else {
            ensurePath(Array(path.dropFirst()), in: &sub)
            dict[head] = sub
        }
    }

    private static func setValue(_ value: Any, at path: [String], in dict: inout [String: Any]) {
        guard let head = path.first else { return }
        if path.count == 1 {
            dict[head] = value
            return
        }
        var sub = dict[head] as? [String: Any] ?? [:]
        setValue(value, at: Array(path.dropFirst()), in: &sub)
        dict[head] = sub
    }
}
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
swift test --filter TOMLParserTests
```

Expected: 5 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Sources/HyprmonCore/Config/TOMLParser.swift Tests/HyprmonCoreTests/TOMLParserTests.swift
git commit -m "feat(config): minimal embedded TOML parser with tests"
```

### Task 8: Config decode from parsed dict — failing test

**Files:**
- Modify: `Sources/HyprmonCore/Config/Config.swift`
- Create: `Tests/HyprmonCoreTests/ConfigTests.swift`

- [ ] **Step 1: Write decode test**

```swift
import XCTest
@testable import HyprmonCore

final class ConfigTests: XCTestCase {
    func testDecodeFullConfig() throws {
        let toml = """
        corner = "bottom-left"
        margin = 20
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
        XCTAssertEqual(cfg.corner, .bottomLeft)
        XCTAssertEqual(cfg.margin, 20)
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
        XCTAssertEqual(cfg.corner, .topRight)     // default
        XCTAssertEqual(cfg.refreshMs, 1000)       // default
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
}
```

- [ ] **Step 2: Run test, verify it fails**

```bash
swift test --filter ConfigTests
```

Expected: build error — `Config.decode` undefined.

### Task 9: Implement Config.decode

**Files:**
- Modify: `Sources/HyprmonCore/Config/Config.swift`

- [ ] **Step 1: Append decode logic to `Config.swift`**

Add at the end of `Sources/HyprmonCore/Config/Config.swift`:

```swift
public extension Config {
    static func decode(from dict: [String: Any]) throws -> Config {
        var c = Config()

        if let s = dict["corner"] as? String, let v = Corner(rawValue: s) { c.corner = v }
        if let v = dict["margin"]  as? Int    { c.margin = v }
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
            if let s = cl["plan"] as? String, let v = Plan(rawValue: s) { c.claude.plan = v }
            if let v = cl["show_5h"]     as? Bool { c.claude.show5h = v }
            if let v = cl["show_weekly"] as? Bool { c.claude.showWeekly = v }
            if let limits = cl["limits"] as? [String: Any] {
                if let v = limits["window_5h_tokens"]     as? Int { c.claude.window5hTokens = v }
                if let v = limits["window_weekly_tokens"] as? Int { c.claude.windowWeeklyTokens = v }
            }
        }
        return c
    }
}
```

- [ ] **Step 2: Run tests, verify they pass**

```bash
swift test --filter ConfigTests
```

Expected: 3 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Sources/HyprmonCore/Config/Config.swift Tests/HyprmonCoreTests/ConfigTests.swift
git commit -m "feat(config): decode Config from parsed TOML dict"
```

### Task 10: ConfigLoader with FSEvents

**Files:**
- Create: `Sources/HyprmonCore/Config/ConfigLoader.swift`

This component is tricky to TDD because of FSEvents. We unit-test the file-loading half and smoke-test the watcher manually.

- [ ] **Step 1: Add a load-from-disk test**

Append to `Tests/HyprmonCoreTests/ConfigTests.swift` (inside the existing `ConfigTests` class):

```swift
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
```

- [ ] **Step 2: Run test, verify it fails**

```bash
swift test --filter ConfigTests/testLoadFromDiskReadsFile
```

Expected: build error — `ConfigLoader` undefined.

- [ ] **Step 3: Implement ConfigLoader**

```swift
import Foundation
import CoreServices

public final class ConfigLoader {
    public static func loadFromDisk(at path: String) throws -> Config {
        guard FileManager.default.fileExists(atPath: path) else {
            return .default
        }
        let data = try String(contentsOfFile: path, encoding: .utf8)
        let dict = try TOMLParser.parse(data)
        return try Config.decode(from: dict)
    }

    // MARK: - Live reload

    public let path: String
    public private(set) var config: Config
    public var onChange: ((Config) -> Void)?

    private var stream: FSEventStreamRef?

    public init(path: String) throws {
        self.path = path
        self.config = try Self.loadFromDisk(at: path)
    }

    public func startWatching() {
        guard stream == nil else { return }
        let dir = (path as NSString).deletingLastPathComponent
        let paths = [dir] as CFArray
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, _, _, _ in
            guard let info = info else { return }
            let loader = Unmanaged<ConfigLoader>.fromOpaque(info).takeUnretainedValue()
            loader.handleEvent()
        }
        let s = FSEventStreamCreate(nil, callback, &ctx, paths,
                                    FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                    0.3,
                                    FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents
                                                              | kFSEventStreamCreateFlagNoDefer))
        if let s = s {
            FSEventStreamSetDispatchQueue(s, .main)
            FSEventStreamStart(s)
            self.stream = s
        }
    }

    public func stopWatching() {
        if let s = stream {
            FSEventStreamStop(s)
            FSEventStreamInvalidate(s)
            FSEventStreamRelease(s)
            stream = nil
        }
    }

    deinit { stopWatching() }

    private func handleEvent() {
        guard let newCfg = try? Self.loadFromDisk(at: path) else {
            NSLog("hyprmon: invalid TOML, keeping previous config")
            return
        }
        if newCfg != config {
            config = newCfg
            onChange?(newCfg)
        }
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

```bash
swift test --filter ConfigTests
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/HyprmonCore/Config/ConfigLoader.swift Tests/HyprmonCoreTests/ConfigTests.swift
git commit -m "feat(config): ConfigLoader with FSEvents live reload"
```

---

## Phase 3 — Sampling

### Task 11: CPUSampler — failing test

**Files:**
- Create: `Tests/HyprmonCoreTests/CPUSamplerTests.swift`

- [ ] **Step 1: Write test**

```swift
import XCTest
@testable import HyprmonCore

final class CPUSamplerTests: XCTestCase {
    func testComputesPercentageFromTickDeltas() {
        // Simulate two samples 1s apart: 800 ticks used out of 1000 total = 80%.
        let prev = CPUSampler.Snapshot(user: 100, system: 100, idle: 800, nice: 0)
        let curr = CPUSampler.Snapshot(user: 700, system: 200, idle: 1000, nice: 0)
        let pct = CPUSampler.percentage(from: prev, to: curr)
        // used delta = (700-100)+(200-100)+(0-0) = 700
        // idle delta = 1000-800 = 200
        // pct = 700 / (700+200) = 0.777...
        XCTAssertEqual(pct, 700.0 / 900.0, accuracy: 0.0001)
    }

    func testReturnsZeroWhenNoDelta() {
        let snap = CPUSampler.Snapshot(user: 100, system: 100, idle: 800, nice: 0)
        XCTAssertEqual(CPUSampler.percentage(from: snap, to: snap), 0.0)
    }
}
```

- [ ] **Step 2: Verify fail**

```bash
swift test --filter CPUSamplerTests
```

Expected: build error — `CPUSampler` undefined.

### Task 12: Implement CPUSampler

**Files:**
- Create: `Sources/HyprmonCore/Sampling/CPUSampler.swift`

- [ ] **Step 1: Write the sampler**

```swift
import Foundation
import Darwin

public final class CPUSampler: @unchecked Sendable {
    public struct Snapshot: Equatable, Sendable {
        public var user: UInt64
        public var system: UInt64
        public var idle: UInt64
        public var nice: UInt64
    }

    private var last: Snapshot?

    public init() {}

    /// Returns CPU usage as fraction 0...1, or nil if no previous sample.
    public func sample() -> Double? {
        guard let snap = Self.readHost() else { return nil }
        defer { last = snap }
        guard let prev = last else { return nil }
        return Self.percentage(from: prev, to: snap)
    }

    public static func percentage(from prev: Snapshot, to curr: Snapshot) -> Double {
        let userΔ   = Double(curr.user   &- prev.user)
        let systemΔ = Double(curr.system &- prev.system)
        let niceΔ   = Double(curr.nice   &- prev.nice)
        let idleΔ   = Double(curr.idle   &- prev.idle)
        let used = userΔ + systemΔ + niceΔ
        let total = used + idleΔ
        return total > 0 ? used / total : 0
    }

    static func readHost() -> Snapshot? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return Snapshot(
            user:   UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle:   UInt64(info.cpu_ticks.2),
            nice:   UInt64(info.cpu_ticks.3)
        )
    }
}
```

- [ ] **Step 2: Run tests**

```bash
swift test --filter CPUSamplerTests
```

Expected: 2 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Sources/HyprmonCore/Sampling/CPUSampler.swift Tests/HyprmonCoreTests/CPUSamplerTests.swift
git commit -m "feat(sampling): CPUSampler via host_statistics + tests"
```

### Task 13: MemorySampler with test

**Files:**
- Create: `Sources/HyprmonCore/Sampling/MemorySampler.swift`
- Create: `Tests/HyprmonCoreTests/MemorySamplerTests.swift`

- [ ] **Step 1: Write test (pure-arithmetic helper)**

```swift
import XCTest
@testable import HyprmonCore

final class MemorySamplerTests: XCTestCase {
    func testComputesUsagePercent() {
        // 1000 page-units total, 600 used, page size 1 → 60%.
        let s = MemorySampler.Snapshot(wired: 200, active: 300, compressed: 100, pageSize: 1, total: 1000)
        XCTAssertEqual(s.usedFraction, 0.6, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Implement sampler**

```swift
import Foundation
import Darwin

public final class MemorySampler: @unchecked Sendable {
    public struct Snapshot: Sendable {
        public var wired: UInt64
        public var active: UInt64
        public var compressed: UInt64
        public var pageSize: UInt64
        public var total: UInt64
        public var usedBytes: UInt64 { (wired + active + compressed) * pageSize }
        public var usedFraction: Double {
            total > 0 ? Double(usedBytes) / Double(total) : 0
        }
    }

    private let totalBytes: UInt64

    public init() {
        self.totalBytes = Self.readTotal()
    }

    public func sample() -> Snapshot? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        var page: vm_size_t = 0
        host_page_size(mach_host_self(), &page)
        return Snapshot(
            wired:      UInt64(stats.wire_count),
            active:     UInt64(stats.active_count),
            compressed: UInt64(stats.compressor_page_count),
            pageSize:   UInt64(page),
            total:      totalBytes
        )
    }

    private static func readTotal() -> UInt64 {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return size
    }
}
```

- [ ] **Step 3: Run tests**

```bash
swift test --filter MemorySamplerTests
```

Expected: 1 test passes.

- [ ] **Step 4: Commit**

```bash
git add Sources/HyprmonCore/Sampling/MemorySampler.swift Tests/HyprmonCoreTests/MemorySamplerTests.swift
git commit -m "feat(sampling): MemorySampler via host_statistics64"
```

### Task 14: BatterySampler (no unit test — IOKit-heavy, smoke test manually)

**Files:**
- Create: `Sources/HyprmonCore/Sampling/BatterySampler.swift`

- [ ] **Step 1: Implement sampler**

```swift
import Foundation
import IOKit
import IOKit.ps

public struct BatteryState: Sendable, Equatable {
    public var percent: Int
    public var isCharging: Bool
    public var isPresent: Bool
    public var timeToEmptyMinutes: Int?     // nil if charging or unknown
}

public final class BatterySampler: @unchecked Sendable {
    public init() {}

    public func sample() -> BatteryState {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let src = list.first,
              let desc = IOPSGetPowerSourceDescription(blob, src)?.takeUnretainedValue() as? [String: Any]
        else {
            return BatteryState(percent: 0, isCharging: false, isPresent: false, timeToEmptyMinutes: nil)
        }
        let percent  = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 0
        let charging = desc[kIOPSIsChargingKey as String] as? Bool ?? false
        let toEmpty  = desc[kIOPSTimeToEmptyKey as String] as? Int
        let isPresent = (desc[kIOPSTypeKey as String] as? String) == kIOPSInternalBatteryType as String
        return BatteryState(
            percent: percent,
            isCharging: charging,
            isPresent: isPresent,
            timeToEmptyMinutes: (toEmpty.flatMap { $0 > 0 ? $0 : nil })
        )
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
swift build --target HyprmonCore
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/HyprmonCore/Sampling/BatterySampler.swift
git commit -m "feat(sampling): BatterySampler via IOPowerSources"
```

### Task 15: ProcessSampler — failing test for delta logic

**Files:**
- Create: `Tests/HyprmonCoreTests/ProcessSamplerTests.swift`

- [ ] **Step 1: Write test**

```swift
import XCTest
@testable import HyprmonCore

final class ProcessSamplerTests: XCTestCase {
    func testTopAggregatesByNameSortsByCPU() {
        let snap1: [Int: ProcessSampler.Sample] = [
            1: .init(pid: 1, name: "Chrome", cpuNs: 1_000_000_000, rss: 100),
            2: .init(pid: 2, name: "Chrome", cpuNs: 2_000_000_000, rss: 100),
            3: .init(pid: 3, name: "Xcode",  cpuNs: 5_000_000_000, rss: 200),
            4: .init(pid: 4, name: "claude", cpuNs:   500_000_000, rss:  50),
        ]
        let snap2: [Int: ProcessSampler.Sample] = [
            1: .init(pid: 1, name: "Chrome", cpuNs: 1_300_000_000, rss: 100),  // +0.3s
            2: .init(pid: 2, name: "Chrome", cpuNs: 2_700_000_000, rss: 100),  // +0.7s → Chrome total +1.0s
            3: .init(pid: 3, name: "Xcode",  cpuNs: 7_000_000_000, rss: 200),  // +2.0s
            4: .init(pid: 4, name: "claude", cpuNs:   600_000_000, rss:  50),  // +0.1s
        ]
        let top = ProcessSampler.top(prev: snap1, curr: snap2, intervalNs: 1_000_000_000, count: 3)
        XCTAssertEqual(top.count, 3)
        XCTAssertEqual(top[0].name, "Xcode")
        XCTAssertEqual(top[0].cpuPct, 2.0, accuracy: 0.001)
        XCTAssertEqual(top[1].name, "Chrome")
        XCTAssertEqual(top[1].cpuPct, 1.0, accuracy: 0.001)
        XCTAssertEqual(top[2].name, "claude")
        XCTAssertEqual(top[2].cpuPct, 0.1, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Verify fail**

```bash
swift test --filter ProcessSamplerTests
```

Expected: build error — `ProcessSampler` undefined.

### Task 16: Implement ProcessSampler

**Files:**
- Create: `Sources/HyprmonCore/Sampling/ProcessSampler.swift`

- [ ] **Step 1: Write the sampler**

```swift
import Foundation
import Darwin

public final class ProcessSampler: @unchecked Sendable {
    public struct Sample: Sendable {
        public let pid: Int
        public let name: String
        public let cpuNs: UInt64   // cumulative CPU time in nanoseconds
        public let rss: UInt64     // resident size in bytes
        public init(pid: Int, name: String, cpuNs: UInt64, rss: UInt64) {
            self.pid = pid; self.name = name; self.cpuNs = cpuNs; self.rss = rss
        }
    }

    public struct Aggregate: Sendable {
        public var name: String
        public var cpuPct: Double   // fraction of 1 core, can exceed 1.0 on multi-core
        public var rss: UInt64
    }

    private var prev: [Int: Sample] = [:]
    private var lastTickNs: UInt64 = 0

    public init() {}

    public func sample(count: Int = 5) -> [Aggregate] {
        let now = Self.nowNs()
        let curr = Self.readAll()
        defer {
            prev = curr
            lastTickNs = now
        }
        guard lastTickNs > 0 else { return [] }
        let interval = max(now - lastTickNs, 1)
        return Self.top(prev: prev, curr: curr, intervalNs: interval, count: count)
    }

    public static func top(prev: [Int: Sample], curr: [Int: Sample], intervalNs: UInt64, count: Int) -> [Aggregate] {
        var byName: [String: (cpuNs: UInt64, rss: UInt64)] = [:]
        for (pid, c) in curr {
            let pNs = prev[pid]?.cpuNs ?? c.cpuNs
            let deltaNs = c.cpuNs &- pNs
            var entry = byName[c.name] ?? (0, 0)
            entry.cpuNs += deltaNs
            entry.rss   += c.rss
            byName[c.name] = entry
        }
        let aggs = byName.map { (name, v) in
            Aggregate(name: name, cpuPct: Double(v.cpuNs) / Double(intervalNs), rss: v.rss)
        }
        return aggs.sorted { $0.cpuPct > $1.cpuPct }.prefix(count).map { $0 }
    }

    // MARK: - libproc reading

    private static func readAll() -> [Int: Sample] {
        let bufSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufSize > 0 else { return [:] }
        let nPids = Int(bufSize) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: nPids)
        let actual = pids.withUnsafeMutableBufferPointer { buf in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, buf.baseAddress, bufSize)
        }
        guard actual > 0 else { return [:] }
        let count = Int(actual) / MemoryLayout<pid_t>.size

        var out: [Int: Sample] = [:]
        for i in 0..<count {
            let pid = pids[i]
            guard pid > 0 else { continue }
            var info = proc_taskinfo()
            let size = MemoryLayout<proc_taskinfo>.size
            let res = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
                proc_pidinfo(pid, PROC_PIDTASKINFO, 0, ptr, Int32(size))
            }
            guard res == Int32(size) else { continue }

            var pathBuf = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
            let plen = proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
            let name: String
            if plen > 0, let s = String(validatingUTF8: pathBuf) {
                name = (s as NSString).lastPathComponent
            } else {
                name = "pid:\(pid)"
            }
            out[Int(pid)] = Sample(
                pid: Int(pid),
                name: name,
                cpuNs: info.pti_total_user &+ info.pti_total_system,
                rss: info.pti_resident_size
            )
        }
        return out
    }

    private static func nowNs() -> UInt64 {
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        return UInt64(ts.tv_sec) * 1_000_000_000 &+ UInt64(ts.tv_nsec)
    }
}
```

- [ ] **Step 2: Run tests**

```bash
swift test --filter ProcessSamplerTests
```

Expected: 1 test passes.

- [ ] **Step 3: Commit**

```bash
git add Sources/HyprmonCore/Sampling/ProcessSampler.swift Tests/HyprmonCoreTests/ProcessSamplerTests.swift
git commit -m "feat(sampling): ProcessSampler with per-name aggregation"
```

### Task 17: SystemSampler orchestrator

**Files:**
- Create: `Sources/HyprmonCore/Sampling/SystemSampler.swift`

- [ ] **Step 1: Write the orchestrator**

```swift
import Foundation
import Observation

@MainActor
@Observable
public final class SystemSampler {
    public private(set) var cpu: Double = 0
    public private(set) var ram: Double = 0
    public private(set) var battery: BatteryState = .init(percent: 0, isCharging: false, isPresent: false, timeToEmptyMinutes: nil)
    public private(set) var topProcs: [ProcessSampler.Aggregate] = []

    private let cpuS = CPUSampler()
    private let memS = MemorySampler()
    private let batS = BatterySampler()
    private let procS = ProcessSampler()
    private var timer: Timer?
    private var intervalMs: Int = 1000
    private var procCount: Int = 5

    public init() {}

    public func start(intervalMs: Int, processCount: Int) {
        self.intervalMs = intervalMs
        self.procCount = processCount
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Double(intervalMs) / 1000.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        if let v = cpuS.sample() { cpu = v }
        if let v = memS.sample() { ram = v.usedFraction }
        battery = batS.sample()
        topProcs = procS.sample(count: procCount)
    }
}
```

- [ ] **Step 2: Build to confirm**

```bash
swift build --target HyprmonCore
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/HyprmonCore/Sampling/SystemSampler.swift
git commit -m "feat(sampling): SystemSampler orchestrator using @Observable"
```

---

## Phase 4 — Claude Usage

### Task 18: PlanLimits

**Files:**
- Create: `Sources/HyprmonCore/Claude/PlanLimits.swift`

- [ ] **Step 1: Write the module**

```swift
import Foundation

public struct PlanLimits: Sendable, Equatable {
    public var window5h: Int
    public var weekly: Int?      // nil = soft (Pro has no clear weekly cap)

    public static func forPlan(_ plan: Config.Plan, custom: Config.ClaudeOpts) -> PlanLimits {
        switch plan {
        case .pro:    return .init(window5h:   45_000, weekly: nil)
        case .max5:   return .init(window5h:  220_000, weekly: 1_500_000)
        case .max20:  return .init(window5h:  880_000, weekly: 6_000_000)
        case .custom:
            return .init(
                window5h: custom.window5hTokens ?? 880_000,
                weekly:   custom.windowWeeklyTokens
            )
        }
    }
}
```

- [ ] **Step 2: Build & commit**

```bash
swift build --target HyprmonCore
git add Sources/HyprmonCore/Claude/PlanLimits.swift
git commit -m "feat(claude): PlanLimits for pro/max5/max20/custom"
```

### Task 19: RollingWindow — failing test

**Files:**
- Create: `Tests/HyprmonCoreTests/RollingWindowTests.swift`

- [ ] **Step 1: Write test**

```swift
import XCTest
@testable import HyprmonCore

final class RollingWindowTests: XCTestCase {
    func testSumsWithinWindow() {
        var w = RollingWindow(durationSeconds: 300)
        let now = Date(timeIntervalSince1970: 1_000_000)
        w.add(timestamp: now.addingTimeInterval(-100), tokens: 50)
        w.add(timestamp: now.addingTimeInterval(-50),  tokens: 30)
        w.add(timestamp: now.addingTimeInterval(-10),  tokens: 20)
        XCTAssertEqual(w.totalTokens(asOf: now), 100)
    }

    func testPrunesOldEvents() {
        var w = RollingWindow(durationSeconds: 300)
        let now = Date(timeIntervalSince1970: 1_000_000)
        w.add(timestamp: now.addingTimeInterval(-1000), tokens: 99)   // out of window
        w.add(timestamp: now.addingTimeInterval(-100),  tokens: 50)
        XCTAssertEqual(w.totalTokens(asOf: now), 50)
        w.prune(asOf: now)
        XCTAssertEqual(w.eventCount, 1)
    }

    func testResetTime() {
        var w = RollingWindow(durationSeconds: 300)
        let now = Date(timeIntervalSince1970: 1_000_000)
        w.add(timestamp: now.addingTimeInterval(-250), tokens: 10)
        w.add(timestamp: now.addingTimeInterval(-100), tokens: 10)
        // Oldest in-window event is at now-250; window is 300; reset is at now-250+300 = now+50.
        XCTAssertEqual(w.resetDate(asOf: now)?.timeIntervalSince(now), 50, accuracy: 0.01)
    }

    func testResetTimeNilWhenEmpty() {
        let w = RollingWindow(durationSeconds: 300)
        XCTAssertNil(w.resetDate(asOf: Date()))
    }
}
```

- [ ] **Step 2: Verify fail**

```bash
swift test --filter RollingWindowTests
```

### Task 20: Implement RollingWindow

**Files:**
- Create: `Sources/HyprmonCore/Claude/RollingWindow.swift`

- [ ] **Step 1: Write**

```swift
import Foundation

public struct RollingWindow: Sendable {
    public let durationSeconds: TimeInterval
    private var events: [(Date, Int)] = []  // (timestamp, tokens)

    public init(durationSeconds: TimeInterval) {
        self.durationSeconds = durationSeconds
    }

    public var eventCount: Int { events.count }

    public mutating func add(timestamp: Date, tokens: Int) {
        events.append((timestamp, tokens))
    }

    public mutating func prune(asOf now: Date) {
        let cutoff = now.addingTimeInterval(-durationSeconds)
        events.removeAll { $0.0 < cutoff }
    }

    public func totalTokens(asOf now: Date) -> Int {
        let cutoff = now.addingTimeInterval(-durationSeconds)
        return events.reduce(0) { acc, ev in ev.0 >= cutoff ? acc + ev.1 : acc }
    }

    public func resetDate(asOf now: Date) -> Date? {
        let cutoff = now.addingTimeInterval(-durationSeconds)
        let oldest = events.filter { $0.0 >= cutoff }.map { $0.0 }.min()
        return oldest.map { $0.addingTimeInterval(durationSeconds) }
    }
}
```

- [ ] **Step 2: Run tests**

```bash
swift test --filter RollingWindowTests
```

Expected: 4 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Sources/HyprmonCore/Claude/RollingWindow.swift Tests/HyprmonCoreTests/RollingWindowTests.swift
git commit -m "feat(claude): RollingWindow with token sums and reset-time"
```

### Task 21: ClaudeUsageReader — failing test

**Files:**
- Create: `Tests/HyprmonCoreTests/ClaudeUsageReaderTests.swift`

- [ ] **Step 1: Write fixture-based test**

```swift
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
            (now.addingTimeInterval(-60),     100, 200, 0, 0),   // sum 300 (in 5h)
            (now.addingTimeInterval(-3600),    50,  50, 100, 0), // sum 200 (in 5h)
            (now.addingTimeInterval(-3600*8),  10,  10,   0, 0), // sum 20 (out of 5h, in 7d)
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
        // Append a junk line without usage.
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
```

- [ ] **Step 2: Verify fail**

```bash
swift test --filter ClaudeUsageReaderTests
```

### Task 22: Implement ClaudeUsageReader

**Files:**
- Create: `Sources/HyprmonCore/Claude/ClaudeUsageReader.swift`

- [ ] **Step 1: Write reader**

```swift
import Foundation

public struct ClaudeUsageSnapshot: Sendable {
    public var window5h: RollingWindow
    public var weekly:   RollingWindow
}

public final class ClaudeUsageReader: @unchecked Sendable {
    public let root: URL                     // typically ~/.claude
    private var offsets: [String: UInt64] = [:]   // path -> bytes read
    private var window5h = RollingWindow(durationSeconds: 5 * 3600)
    private var weekly   = RollingWindow(durationSeconds: 7 * 86400)
    private let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let isoParserNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")) {
        self.root = root
    }

    public func read(asOf now: Date = Date()) -> ClaudeUsageSnapshot {
        let projects = root.appendingPathComponent("projects")
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: projects, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return snapshot(now: now)
        }
        let cutoff = now.addingTimeInterval(-8 * 86400)  // skip files untouched for > 8d
        while let url = walker.nextObject() as? URL {
            guard url.pathExtension == "jsonl" else { continue }
            let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            if let mtime = attrs?.contentModificationDate, mtime < cutoff { continue }
            ingest(file: url, now: now)
        }
        window5h.prune(asOf: now)
        weekly.prune(asOf: now)
        return snapshot(now: now)
    }

    private func snapshot(now: Date) -> ClaudeUsageSnapshot {
        ClaudeUsageSnapshot(window5h: window5h, weekly: weekly)
    }

    private func ingest(file: URL, now: Date) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return }
        defer { try? handle.close() }

        let path = file.path
        let startOffset = offsets[path] ?? 0

        // Detect truncation/rotation: if file size < cached offset, reset.
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? NSNumber)?.uint64Value ?? 0
        let from: UInt64
        if size < startOffset {
            from = 0
        } else {
            from = startOffset
        }

        try? handle.seek(toOffset: from)
        guard let data = try? handle.readToEnd() else { return }
        offsets[path] = from + UInt64(data.count)

        guard let text = String(data: data, encoding: .utf8) else { return }
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            parseLine(String(raw))
        }
    }

    private func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        guard let tsStr = obj["timestamp"] as? String,
              let ts = isoParser.date(from: tsStr) ?? isoParserNoFrac.date(from: tsStr) else { return }
        guard let msg = obj["message"] as? [String: Any],
              let usage = msg["usage"] as? [String: Any] else { return }
        let tokens =
            (usage["input_tokens"]  as? Int ?? 0) +
            (usage["output_tokens"] as? Int ?? 0) +
            (usage["cache_creation_input_tokens"] as? Int ?? 0) +
            (usage["cache_read_input_tokens"]    as? Int ?? 0)
        if tokens == 0 { return }
        window5h.add(timestamp: ts, tokens: tokens)
        weekly.add(timestamp: ts, tokens: tokens)
    }
}
```

- [ ] **Step 2: Run tests**

```bash
swift test --filter ClaudeUsageReaderTests
```

Expected: 2 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Sources/HyprmonCore/Claude/ClaudeUsageReader.swift Tests/HyprmonCoreTests/ClaudeUsageReaderTests.swift
git commit -m "feat(claude): ClaudeUsageReader with incremental JSONL tail"
```

### Task 23: ClaudeMonitor that exposes @Observable state

**Files:**
- Create: `Sources/HyprmonCore/Claude/ClaudeMonitor.swift`

- [ ] **Step 1: Write monitor**

```swift
import Foundation
import Observation

@MainActor
@Observable
public final class ClaudeMonitor {
    public private(set) var tokens5h: Int = 0
    public private(set) var tokensWeekly: Int = 0
    public private(set) var resetAt5h: Date?
    public private(set) var resetAtWeekly: Date?
    public private(set) var limits: PlanLimits = .init(window5h: 880_000, weekly: 6_000_000)

    private let reader: ClaudeUsageReader
    private var timer: Timer?

    public init(reader: ClaudeUsageReader = .init()) {
        self.reader = reader
    }

    public func start(intervalMs: Int, plan: Config.Plan, claudeCfg: Config.ClaudeOpts) {
        limits = PlanLimits.forPlan(plan, custom: claudeCfg)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Double(intervalMs) / 1000.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    public func stop() { timer?.invalidate(); timer = nil }

    public var fraction5h: Double {
        guard limits.window5h > 0 else { return 0 }
        return min(Double(tokens5h) / Double(limits.window5h), 1.0)
    }

    public var fractionWeekly: Double? {
        guard let w = limits.weekly, w > 0 else { return nil }
        return min(Double(tokensWeekly) / Double(w), 1.0)
    }

    private func tick() {
        let now = Date()
        let snap = reader.read(asOf: now)
        tokens5h     = snap.window5h.totalTokens(asOf: now)
        tokensWeekly = snap.weekly.totalTokens(asOf: now)
        resetAt5h     = snap.window5h.resetDate(asOf: now)
        resetAtWeekly = snap.weekly.resetDate(asOf: now)
    }
}
```

- [ ] **Step 2: Build & commit**

```bash
swift build --target HyprmonCore
git add Sources/HyprmonCore/Claude/ClaudeMonitor.swift
git commit -m "feat(claude): ClaudeMonitor wraps reader behind @Observable state"
```

---

## Phase 5 — Views

> **Note:** View code is tested manually — we verify visually after each compile. No unit tests for SwiftUI views.

### Task 24: SectionHeader and MetricBar

**Files:**
- Create: `Sources/hyprmon/Views/SectionHeader.swift`
- Create: `Sources/hyprmon/Views/MetricBar.swift`

- [ ] **Step 1: Write `SectionHeader.swift`**

```swift
import SwiftUI
import HyprmonCore

struct SectionHeader: View {
    let title: String
    let theme: Theme

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1)
            .foregroundStyle(theme.fgMuted)
    }
}
```

- [ ] **Step 2: Write `MetricBar.swift`**

```swift
import SwiftUI
import HyprmonCore

struct MetricBar: View {
    let label: String
    let value: Double          // 0...1
    let display: String        // formatted right-hand display, e.g. "42%"
    let theme: Theme
    var trailing: String? = nil  // optional small icon/string, e.g. "⚡"

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.fgMuted)
                .frame(width: 28, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(theme.trackBg)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(theme.heatColor(for: value))
                        .frame(width: max(0, min(value, 1)) * proxy.size.width, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: value)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 14)

            Text(display)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.fgPrimary)
                .frame(width: 36, alignment: .trailing)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.accent)
                    .frame(width: 10, alignment: .leading)
            } else {
                Color.clear.frame(width: 10)
            }
        }
        .frame(height: 16)
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
swift build
```

Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/hyprmon/Views/SectionHeader.swift Sources/hyprmon/Views/MetricBar.swift
git commit -m "feat(views): SectionHeader and MetricBar primitives"
```

### Task 25: BatteryRow

**Files:**
- Create: `Sources/hyprmon/Views/BatteryRow.swift`

Battery uses an inverse heat-map (low battery → danger), so we render directly instead of reusing `MetricBar`.

- [ ] **Step 1: Write `BatteryRow.swift`**

```swift
import SwiftUI
import HyprmonCore

struct BatteryRow: View {
    let state: BatteryState
    let theme: Theme

    private var fillColor: Color {
        // Inverse of heat: low battery → danger, mid → warn, high → ok.
        switch state.percent {
        case ..<20:  return theme.danger
        case ..<50:  return theme.warn
        default:     return theme.ok
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("BAT")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.fgMuted)
                .frame(width: 28, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(theme.trackBg)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fillColor)
                        .frame(width: proxy.size.width * Double(state.percent) / 100.0, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: state.percent)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 14)

            Text("\(state.percent)%")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.fgPrimary)
                .frame(width: 36, alignment: .trailing)

            Text(state.isCharging ? "⚡" : "")
                .font(.system(size: 11))
                .foregroundStyle(theme.accent)
                .frame(width: 10, alignment: .leading)
        }
        .frame(height: 16)
    }
}
```

- [ ] **Step 2: Build & commit**

```bash
swift build
git add Sources/hyprmon/Views/BatteryRow.swift
git commit -m "feat(views): BatteryRow with inverse heat-map"
```

### Task 26: ProcessTable

**Files:**
- Create: `Sources/hyprmon/Views/ProcessTable.swift`

- [ ] **Step 1: Write**

```swift
import SwiftUI
import HyprmonCore

struct ProcessTable: View {
    let procs: [ProcessSampler.Aggregate]
    let theme: Theme

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(procs.enumerated()), id: \.offset) { _, p in
                HStack {
                    Text(p.name)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.fgPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    Text(String(format: "%.1f%%", p.cpuPct * 100))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(theme.fgMuted)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build & commit**

```bash
swift build
git add Sources/hyprmon/Views/ProcessTable.swift
git commit -m "feat(views): ProcessTable row list"
```

### Task 27: ClaudeQuotaView

**Files:**
- Create: `Sources/hyprmon/Views/ClaudeQuotaView.swift`

- [ ] **Step 1: Write**

```swift
import SwiftUI
import HyprmonCore

struct ClaudeQuotaView: View {
    let monitor: ClaudeMonitor
    let cfg: Config.ClaudeOpts
    let theme: Theme

    var body: some View {
        VStack(spacing: 6) {
            if cfg.show5h {
                MetricBar(
                    label: "5H",
                    value: monitor.fraction5h,
                    display: String(format: "%.0f%%", monitor.fraction5h * 100),
                    theme: theme
                )
                if let resetAt = monitor.resetAt5h {
                    HStack {
                        Spacer()
                        Text("resets in \(formatRemaining(from: resetAt))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.fgMuted)
                    }
                }
            }
            if cfg.showWeekly, let frac = monitor.fractionWeekly {
                MetricBar(
                    label: "7D",
                    value: frac,
                    display: String(format: "%.0f%%", frac * 100),
                    theme: theme
                )
                if let resetAt = monitor.resetAtWeekly {
                    HStack {
                        Spacer()
                        Text("resets in \(formatRemaining(from: resetAt))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.fgMuted)
                    }
                }
            }
        }
    }

    private func formatRemaining(from date: Date) -> String {
        let secs = max(date.timeIntervalSinceNow, 0)
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        if h >= 24 {
            let d = h / 24
            let rh = h % 24
            return "\(d)d \(String(format: "%02d", rh))h"
        }
        return "\(h)h \(String(format: "%02d", m))m"
    }
}
```

- [ ] **Step 2: Build & commit**

```bash
swift build
git add Sources/hyprmon/Views/ClaudeQuotaView.swift
git commit -m "feat(views): ClaudeQuotaView with 5h and weekly bars + reset countdowns"
```

### Task 28: ContentView

**Files:**
- Create: `Sources/hyprmon/Views/ContentView.swift`

- [ ] **Step 1: Write**

```swift
import SwiftUI
import HyprmonCore

struct ContentView: View {
    let system: SystemSampler
    let claude: ClaudeMonitor
    let cfg: Config
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "HYPRMON", theme: theme)

            if cfg.modules.cpu || cfg.modules.ram || cfg.modules.battery {
                SectionHeader(title: "System", theme: theme)
                VStack(spacing: 6) {
                    if cfg.modules.cpu {
                        MetricBar(label: "CPU", value: system.cpu,
                                  display: String(format: "%.0f%%", system.cpu * 100), theme: theme)
                    }
                    if cfg.modules.ram {
                        MetricBar(label: "RAM", value: system.ram,
                                  display: String(format: "%.0f%%", system.ram * 100), theme: theme)
                    }
                    if cfg.modules.battery, system.battery.isPresent {
                        BatteryRow(state: system.battery, theme: theme)
                    }
                }
            }

            if cfg.modules.processes, !system.topProcs.isEmpty {
                Divider().background(theme.surface)
                SectionHeader(title: "Top Processes", theme: theme)
                ProcessTable(procs: system.topProcs, theme: theme)
            }

            if cfg.modules.claude {
                Divider().background(theme.surface)
                SectionHeader(title: "Claude", theme: theme)
                ClaudeQuotaView(monitor: claude, cfg: cfg.claude, theme: theme)
            }
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }
}
```

- [ ] **Step 2: Build & commit**

```bash
swift build
git add Sources/hyprmon/Views/ContentView.swift
git commit -m "feat(views): ContentView composes all sections"
```

---

## Phase 6 — Desktop Panel and App Entry

### Task 29: DesktopPanel (NSPanel at desktop level)

**Files:**
- Create: `Sources/hyprmon/App/DesktopPanel.swift`

- [ ] **Step 1: Write**

```swift
import AppKit
import SwiftUI
import HyprmonCore

final class DesktopPanel: NSPanel {
    init<Root: View>(content: Root, cfg: Config) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 380),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = false
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
        self.isMovableByWindowBackground = false
        self.ignoresMouseEvents = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false

        // Glass effect.
        let effect = NSVisualEffectView()
        effect.material = .underWindowBackground
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])

        self.contentView = effect

        applyConfig(cfg)
        positionFor(corner: cfg.corner, margin: CGFloat(cfg.margin))
    }

    func applyConfig(_ cfg: Config) {
        self.alphaValue = CGFloat(cfg.opacity)
    }

    func positionFor(corner: Config.Corner, margin: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let frame = self.frame
        let visible = screen.visibleFrame
        var origin = CGPoint.zero
        switch corner {
        case .topRight:
            origin = CGPoint(x: visible.maxX - frame.width - margin, y: visible.maxY - frame.height - margin)
        case .topLeft:
            origin = CGPoint(x: visible.minX + margin, y: visible.maxY - frame.height - margin)
        case .bottomRight:
            origin = CGPoint(x: visible.maxX - frame.width - margin, y: visible.minY + margin)
        case .bottomLeft:
            origin = CGPoint(x: visible.minX + margin, y: visible.minY + margin)
        }
        self.setFrameOrigin(origin)
    }

    override var canBecomeKey:  Bool { false }
    override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 2: Build & commit**

```bash
swift build
git add Sources/hyprmon/App/DesktopPanel.swift
git commit -m "feat(app): DesktopPanel — NSPanel at desktop level, ignores mouse"
```

### Task 30: LaunchAgent install/uninstall

**Files:**
- Create: `Sources/hyprmon/App/LaunchAgent.swift`

- [ ] **Step 1: Write**

```swift
import Foundation

enum LaunchAgent {
    static let label = "com.pipe0919.hyprmon"

    static var plistPath: String {
        let home = NSHomeDirectory()
        return "\(home)/Library/LaunchAgents/\(label).plist"
    }

    static func install(binaryPath: String) throws {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [binaryPath],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardErrorPath":  "\(NSHomeDirectory())/Library/Logs/hyprmon.log",
            "StandardOutPath":    "\(NSHomeDirectory())/Library/Logs/hyprmon.log",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let dir = (plistPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: plistPath))
        _ = shell(["/bin/launchctl", "bootstrap", "gui/\(getuid())", plistPath])
        print("Installed LaunchAgent at \(plistPath)")
    }

    static func uninstall() throws {
        _ = shell(["/bin/launchctl", "bootout", "gui/\(getuid())/\(label)"])
        if FileManager.default.fileExists(atPath: plistPath) {
            try FileManager.default.removeItem(atPath: plistPath)
        }
        print("Uninstalled LaunchAgent")
    }

    @discardableResult
    private static func shell(_ args: [String]) -> Int32 {
        let task = Process()
        task.launchPath = args[0]
        task.arguments = Array(args.dropFirst())
        do { try task.run() } catch { return -1 }
        task.waitUntilExit()
        return task.terminationStatus
    }
}
```

- [ ] **Step 2: Build & commit**

```bash
swift build
git add Sources/hyprmon/App/LaunchAgent.swift
git commit -m "feat(app): LaunchAgent install/uninstall via launchctl"
```

### Task 31: Main entry point with CLI flags

**Files:**
- Create: `Sources/hyprmon/main.swift`

- [ ] **Step 1: Write**

```swift
import AppKit
import SwiftUI
import HyprmonCore

let VERSION = "0.1.0"

// CLI flags first — they short-circuit the GUI.
let args = CommandLine.arguments
if args.contains("--version") {
    print("hyprmon \(VERSION)")
    exit(0)
}
if args.contains("--install-agent") {
    do {
        let binary = Bundle.main.executablePath ?? args[0]
        try LaunchAgent.install(binaryPath: binary)
        exit(0)
    } catch {
        FileHandle.standardError.write("install failed: \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}
if args.contains("--uninstall-agent") {
    do { try LaunchAgent.uninstall(); exit(0) }
    catch {
        FileHandle.standardError.write("uninstall failed: \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}

var configPath = "\(NSHomeDirectory())/.config/hyprmon/config.toml"
if let i = args.firstIndex(of: "--config"), i + 1 < args.count {
    configPath = args[i + 1]
}

// Ensure config exists; write defaults if not.
let configDir = (configPath as NSString).deletingLastPathComponent
try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
if !FileManager.default.fileExists(atPath: configPath) {
    let defaults = """
    # ~/.config/hyprmon/config.toml — auto-generated defaults
    corner       = "top-right"
    margin       = 12
    opacity      = 0.85
    accent       = "#7AA2F7"
    refresh_ms   = 1000
    claude_refresh_ms = 30000

    [modules]
    cpu       = true
    ram       = true
    battery   = true
    processes = true
    claude    = true

    [processes]
    count   = 5
    sort_by = "cpu"

    [claude]
    plan        = "max20"
    show_5h     = true
    show_weekly = true
    """
    try? defaults.write(toFile: configPath, atomically: true, encoding: .utf8)
}

// Build the app.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

final class Holder {
    var panel: DesktopPanel?
    let system = SystemSampler()
    let claude = ClaudeMonitor()
    let loader: ConfigLoader
    var cfg: Config
    init(loader: ConfigLoader) {
        self.loader = loader
        self.cfg = loader.config
    }
}

let loader = try ConfigLoader(path: configPath)
let holder = Holder(loader: loader)

@MainActor
func rebuildPanel() {
    let theme = Theme(
        accent: Color(hexString: holder.cfg.accentHex) ?? Theme.default.accent,
        opacity: holder.cfg.opacity
    )
    let content = ContentView(system: holder.system, claude: holder.claude, cfg: holder.cfg, theme: theme)
    if holder.panel == nil {
        holder.panel = DesktopPanel(content: content, cfg: holder.cfg)
        holder.panel?.orderFront(nil)
    } else {
        // Update mutable bits (opacity, corner, theme).
        holder.panel?.applyConfig(holder.cfg)
        holder.panel?.positionFor(corner: holder.cfg.corner, margin: CGFloat(holder.cfg.margin))
        // For theme/accent changes, swap the hosted view.
        if let effect = holder.panel?.contentView as? NSVisualEffectView,
           let host = effect.subviews.compactMap({ $0 as? NSHostingView<ContentView> }).first {
            host.rootView = content
        }
    }
}

loader.onChange = { newCfg in
    Task { @MainActor in
        holder.cfg = newCfg
        holder.system.start(intervalMs: newCfg.refreshMs, processCount: newCfg.processes.count)
        holder.claude.start(intervalMs: newCfg.claudeRefreshMs, plan: newCfg.claude.plan, claudeCfg: newCfg.claude)
        rebuildPanel()
    }
}
loader.startWatching()

Task { @MainActor in
    holder.system.start(intervalMs: holder.cfg.refreshMs, processCount: holder.cfg.processes.count)
    holder.claude.start(intervalMs: holder.cfg.claudeRefreshMs, plan: holder.cfg.claude.plan, claudeCfg: holder.cfg.claude)
    rebuildPanel()
}

app.run()
```

- [ ] **Step 2: Build**

```bash
swift build
```

Expected: `Build complete!` (may take ~10-15s the first time).

- [ ] **Step 3: Smoke-run from CLI**

```bash
swift run hyprmon --version
```

Expected: `hyprmon 0.1.0`.

- [ ] **Step 4: Commit**

```bash
git add Sources/hyprmon/main.swift
git commit -m "feat(app): main entry — CLI flags, config bootstrap, panel lifecycle"
```

---

## Phase 7 — Packaging

### Task 32: build.sh that produces Hyprmon.app

**Files:**
- Create: `build.sh`
- Create: `Resources/Info.plist`

- [ ] **Step 1: Write `Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>      <string>en</string>
    <key>CFBundleExecutable</key>             <string>hyprmon</string>
    <key>CFBundleIdentifier</key>             <string>com.pipe0919.hyprmon</string>
    <key>CFBundleName</key>                   <string>Hyprmon</string>
    <key>CFBundleDisplayName</key>            <string>Hyprmon</string>
    <key>CFBundlePackageType</key>            <string>APPL</string>
    <key>CFBundleShortVersionString</key>     <string>0.1.0</string>
    <key>CFBundleVersion</key>                <string>1</string>
    <key>LSMinimumSystemVersion</key>         <string>13.0</string>
    <key>LSUIElement</key>                    <true/>
    <key>NSHighResolutionCapable</key>        <true/>
    <key>NSPrincipalClass</key>               <string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 2: Write `build.sh`**

```bash
#!/usr/bin/env bash
# Build Hyprmon.app from the SwiftPM executable.
# Usage:
#   ./build.sh            # native (arm64 or x86_64 depending on host)
#   ./build.sh --universal  # universal binary (arm64 + x86_64)
set -euo pipefail

cd "$(dirname "$0")"
OUT_DIR="build"
APP="$OUT_DIR/Hyprmon.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RES_DIR"

UNIVERSAL=false
if [[ "${1:-}" == "--universal" ]]; then UNIVERSAL=true; fi

if $UNIVERSAL; then
    echo "Building universal binary..."
    swift build -c release --triple arm64-apple-macos13.0
    cp .build/arm64-apple-macos13.0/release/hyprmon "$BIN_DIR/hyprmon-arm64"
    swift build -c release --triple x86_64-apple-macos13.0
    cp .build/x86_64-apple-macos13.0/release/hyprmon "$BIN_DIR/hyprmon-x86_64"
    lipo -create "$BIN_DIR/hyprmon-arm64" "$BIN_DIR/hyprmon-x86_64" -output "$BIN_DIR/hyprmon"
    rm "$BIN_DIR/hyprmon-arm64" "$BIN_DIR/hyprmon-x86_64"
else
    echo "Building native..."
    swift build -c release
    cp ".build/release/hyprmon" "$BIN_DIR/hyprmon"
fi

cp Resources/Info.plist "$APP/Contents/Info.plist"
chmod +x "$BIN_DIR/hyprmon"

# Ad-hoc codesign (no hardened runtime; not notarized).
codesign --force --sign - --deep "$APP" >/dev/null
echo "Built $APP"
file "$BIN_DIR/hyprmon"
```

- [ ] **Step 3: Make executable and build**

```bash
chmod +x build.sh
./build.sh
```

Expected: `Built build/Hyprmon.app` and a `file` output showing Mach-O binary.

- [ ] **Step 4: Smoke-run the .app**

```bash
open ./build/Hyprmon.app
```

Expected: panel appears in the top-right corner of the desktop, behind any open windows, showing live CPU/RAM/Bat/processes/Claude data. To stop: `pkill -x hyprmon`.

- [ ] **Step 5: Commit**

```bash
git add build.sh Resources/Info.plist
git commit -m "build: build.sh produces Hyprmon.app (native or universal)"
```

### Task 33: examples/config.toml

**Files:**
- Create: `examples/config.toml`

- [ ] **Step 1: Write**

```toml
# hyprmon configuration — copy to ~/.config/hyprmon/config.toml.
# Edits are picked up live (no restart needed) except for `corner` and `margin`.

# --- panel ---
corner       = "top-right"   # top-right | top-left | bottom-right | bottom-left
margin       = 12             # pixels from the screen edge
opacity      = 0.85           # 0.0 (transparent) to 1.0 (solid)
accent       = "#7AA2F7"      # hex color, used for the small charging ⚡ icon

# --- refresh rates ---
refresh_ms        = 1000      # system metrics tick (default 1s)
claude_refresh_ms = 30000     # claude usage tick (default 30s — JSONL scan is expensive)

# --- which sections to render ---
[modules]
cpu       = true
ram       = true
battery   = true              # ignored on desktop Macs without a battery
processes = true
claude    = true

# --- top processes ---
[processes]
count   = 5
sort_by = "cpu"               # cpu | ram

# --- Claude usage ---
[claude]
plan        = "max20"         # pro | max5 | max20 | custom
show_5h     = true
show_weekly = true            # auto-hidden for `pro` plan (no documented weekly cap)

# Only if plan = "custom":
# [claude.limits]
# window_5h_tokens     = 880000
# window_weekly_tokens = 6000000
```

- [ ] **Step 2: Commit**

```bash
git add examples/config.toml
git commit -m "docs: example config.toml with comments"
```

### Task 34: Makefile

**Files:**
- Create: `Makefile`

- [ ] **Step 1: Write**

```makefile
.PHONY: build test install uninstall clean run

build:
	./build.sh

test:
	swift test

run: build
	open ./build/Hyprmon.app

install: build
	rm -rf /Applications/Hyprmon.app
	cp -R ./build/Hyprmon.app /Applications/
	@echo "Installed to /Applications/Hyprmon.app"
	@echo "Run 'hyprmon --install-agent' to start at login (or open the app manually)."

uninstall:
	rm -rf /Applications/Hyprmon.app
	./build/Hyprmon.app/Contents/MacOS/hyprmon --uninstall-agent 2>/dev/null || true
	@echo "Removed /Applications/Hyprmon.app"

clean:
	rm -rf .build build
```

- [ ] **Step 2: Commit**

```bash
git add Makefile
git commit -m "build: Makefile with build/test/install/uninstall targets"
```

### Task 35: README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write**

````markdown
# hyprmon

A Hyprland-style desktop widget for macOS. Live CPU, RAM, battery, top-5 processes, and Claude Code usage (5-hour and weekly rolling windows) rendered on a non-intrusive glass panel that lives behind your windows.

![screenshot placeholder — add after first build](docs/screenshot.png)

## Install

### Homebrew (recommended)

```bash
brew install pipe0919/tap/hyprmon
open -a Hyprmon
```

To start at login:

```bash
hyprmon --install-agent
```

### From source

```bash
git clone https://github.com/pipe0919/hyprmon
cd hyprmon
./build.sh
open ./build/Hyprmon.app
```

## Configuration

Configuration lives in `~/.config/hyprmon/config.toml`. The file is created with sensible defaults on first run. Edits are picked up live except for `corner` and `margin`.

See [`examples/config.toml`](examples/config.toml) for the full schema.

Common tweaks:

```toml
corner  = "bottom-right"
opacity = 0.7
accent  = "#F7768E"

[claude]
plan = "max5"          # pro | max5 | max20 | custom
```

For `claude.plan = "custom"`:

```toml
[claude]
plan = "custom"

[claude.limits]
window_5h_tokens     = 500000
window_weekly_tokens = 4000000
```

## What gets measured

| Metric | Source |
|---|---|
| CPU % | `host_statistics(HOST_CPU_LOAD_INFO)` deltas across ticks |
| RAM % | `host_statistics64(HOST_VM_INFO64)`, `(wired+active+compressed)/total` |
| Battery | `IOPowerSources` framework |
| Top processes | `proc_listpids` + `proc_pid_taskinfo`, aggregated by executable name |
| Claude 5h / weekly | Sum of tokens from `~/.claude/projects/**/*.jsonl` over rolling windows |

## Requirements

- macOS 13 (Ventura) or newer
- Apple Silicon or Intel (universal binary)

## License

Apache 2.0. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README with install, config, and metric source details"
```

---

## Phase 8 — CI/CD

### Task 36: ci.yml workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-and-test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Show Swift version
        run: swift --version
      - name: Run tests
        run: swift test --parallel
      - name: Build app
        run: ./build.sh
      - name: Verify binary
        run: file build/Hyprmon.app/Contents/MacOS/hyprmon
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: build and test on macos-14"
```

### Task 37: release.yml workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Write**

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  release:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Get version
        id: ver
        run: echo "version=${GITHUB_REF_NAME#v}" >> "$GITHUB_OUTPUT"
      - name: Build universal
        run: ./build.sh --universal
      - name: Verify universal
        run: lipo -info build/Hyprmon.app/Contents/MacOS/hyprmon
      - name: Package
        id: pkg
        run: |
          VERSION="${{ steps.ver.outputs.version }}"
          NAME="hyprmon-${VERSION}.tar.gz"
          tar -C build -czf "$NAME" Hyprmon.app
          SHA=$(shasum -a 256 "$NAME" | awk '{print $1}')
          echo "name=$NAME"  >> "$GITHUB_OUTPUT"
          echo "sha=$SHA"    >> "$GITHUB_OUTPUT"
      - name: Generate Formula
        run: |
          VERSION="${{ steps.ver.outputs.version }}"
          SHA="${{ steps.pkg.outputs.sha }}"
          NAME="${{ steps.pkg.outputs.name }}"
          cat > Formula/hyprmon.rb <<EOF
          class Hyprmon < Formula
            desc "Hyprland-style system monitor widget for macOS (CPU/RAM/battery/processes/Claude usage)"
            homepage "https://github.com/pipe0919/hyprmon"
            url "https://github.com/pipe0919/hyprmon/releases/download/v${VERSION}/${NAME}"
            sha256 "${SHA}"
            license "Apache-2.0"

            depends_on macos: :ventura

            def install
              prefix.install "Hyprmon.app"
              bin.write_exec_script "#{prefix}/Hyprmon.app/Contents/MacOS/hyprmon"
            end

            def caveats
              <<~CAVEATS
                To run on login:
                  hyprmon --install-agent

                Configuration file:
                  ~/.config/hyprmon/config.toml
              CAVEATS
            end

            test do
              system "#{bin}/hyprmon", "--version"
            end
          end
          EOF
      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          VERSION="${{ steps.ver.outputs.version }}"
          gh release create "v${VERSION}" \
            "${{ steps.pkg.outputs.name }}" \
            --title "v${VERSION}" \
            --notes-file CHANGELOG.md
      - name: Push formula to homebrew-tap
        env:
          TAP_TOKEN: ${{ secrets.TAP_TOKEN }}
        run: |
          if [ -z "$TAP_TOKEN" ]; then
            echo "TAP_TOKEN not set — skipping tap update. Set a PAT with repo scope on pipe0919/homebrew-tap as TAP_TOKEN to enable."
            exit 0
          fi
          VERSION="${{ steps.ver.outputs.version }}"
          git clone "https://x-access-token:${TAP_TOKEN}@github.com/pipe0919/homebrew-tap.git" /tmp/tap
          mkdir -p /tmp/tap/Formula
          cp Formula/hyprmon.rb /tmp/tap/Formula/hyprmon.rb
          cd /tmp/tap
          git config user.email "actions@github.com"
          git config user.name  "hyprmon release bot"
          git add Formula/hyprmon.rb
          git commit -m "hyprmon ${VERSION}"
          git push origin main
```

- [ ] **Step 2: Create the placeholder Formula directory and file (CI overwrites on release)**

```bash
mkdir -p Formula
cat > Formula/hyprmon.rb <<'EOF'
# This file is regenerated by .github/workflows/release.yml on every tag.
# Editing it manually has no effect after the next release.
class Hyprmon < Formula
  desc "Hyprland-style system monitor widget for macOS"
  homepage "https://github.com/pipe0919/hyprmon"
  url "https://github.com/pipe0919/hyprmon/releases/download/v0.0.0/placeholder.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "Apache-2.0"

  depends_on macos: :ventura

  def install
    prefix.install "Hyprmon.app"
    bin.write_exec_script "#{prefix}/Hyprmon.app/Contents/MacOS/hyprmon"
  end

  test do
    system "#{bin}/hyprmon", "--version"
  end
end
EOF
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml Formula/hyprmon.rb
git commit -m "ci: release workflow — build universal, package, publish, sync tap"
```

---

## Phase 9 — GitHub Publishing

### Task 38: Push hyprmon repo to GitHub

**Files:** none (uses `gh` CLI).

- [ ] **Step 1: Create the remote repo**

```bash
cd ~/Desktop/hyprmon
gh repo create pipe0919/hyprmon --public \
  --description "Hyprland-style desktop widget for macOS: CPU, RAM, battery, top processes, Claude usage" \
  --homepage "https://github.com/pipe0919/hyprmon" \
  --source . --remote origin --push
```

Expected: repo created and `main` branch pushed. `gh repo view` should now work.

- [ ] **Step 2: Verify**

```bash
gh repo view pipe0919/hyprmon --json url --jq '.url'
```

Expected: `https://github.com/pipe0919/hyprmon`.

### Task 39: Create the homebrew-tap repo

**Files:** none.

- [ ] **Step 1: Create empty tap repo**

```bash
TMP=$(mktemp -d)
cd "$TMP"
git init -q -b main
mkdir Formula
cat > README.md <<'EOF'
# pipe0919/homebrew-tap

Homebrew tap for [hyprmon](https://github.com/pipe0919/hyprmon).

```bash
brew install pipe0919/tap/hyprmon
```
EOF
git add README.md Formula
git commit -q -m "init tap"
gh repo create pipe0919/homebrew-tap --public \
  --description "Homebrew tap for hyprmon" \
  --source . --remote origin --push
```

- [ ] **Step 2: Verify**

```bash
gh repo view pipe0919/homebrew-tap --json url --jq '.url'
```

Expected: `https://github.com/pipe0919/homebrew-tap`.

- [ ] **Step 3: Create a Personal Access Token for tap updates**

> **Manual step (Felipe):** Go to <https://github.com/settings/personal-access-tokens/new>, create a fine-grained token with **Contents: write** on the `pipe0919/homebrew-tap` repo, then add it as `TAP_TOKEN` secret on `pipe0919/hyprmon`:
>
> ```bash
> gh secret set TAP_TOKEN -R pipe0919/hyprmon
> # paste the token when prompted
> ```

This is required for `release.yml` to push the new formula on each release. If skipped, the release still publishes but the tap stays at the previous version.

### Task 40: Tag and release v0.1.0

**Files:** none.

- [ ] **Step 1: Verify everything builds + tests pass once more**

```bash
cd ~/Desktop/hyprmon
swift test
./build.sh
```

Expected: tests pass, `Built build/Hyprmon.app`.

- [ ] **Step 2: Update CHANGELOG.md**

Edit `CHANGELOG.md` to move `[Unreleased]` content under `[0.1.0] - 2026-05-15`. Replace contents with:

```markdown
# Changelog

## [0.1.0] - 2026-05-15

### Added
- Live CPU, RAM, and battery readouts on a desktop-level floating panel.
- Top 5 processes (aggregated by executable name).
- Claude Code usage tracker: 5-hour and weekly rolling windows for Pro/Max5/Max20/custom plans.
- TOML configuration at `~/.config/hyprmon/config.toml` with live reload.
- `hyprmon --install-agent` / `--uninstall-agent` for login startup.
- Homebrew distribution via `pipe0919/homebrew-tap`.
```

- [ ] **Step 3: Commit changelog and tag**

```bash
git add CHANGELOG.md
git commit -m "release: 0.1.0"
git tag v0.1.0
git push origin main
git push origin v0.1.0
```

The `release.yml` workflow runs on the tag push, builds the universal app, packages it, creates the GitHub Release, and (if `TAP_TOKEN` is set) updates the tap.

- [ ] **Step 4: Verify the release succeeded**

```bash
gh run watch -R pipe0919/hyprmon
gh release view v0.1.0 -R pipe0919/hyprmon
```

Expected: release `v0.1.0` exists with `hyprmon-0.1.0.tar.gz` as an asset.

- [ ] **Step 5: Smoke-install via Homebrew**

```bash
brew tap pipe0919/tap
brew install hyprmon
hyprmon --version
```

Expected: `hyprmon 0.1.0`.

---

## Acceptance Criteria

- [ ] `swift test` passes (all tests across CPU, Memory, Process, RollingWindow, ClaudeUsage, TOML, Config).
- [ ] `./build.sh` produces a `Hyprmon.app` that opens and shows live data.
- [ ] Panel renders behind opened windows (Hyprland-style desktop level).
- [ ] Panel does not appear in Dock or Cmd-Tab.
- [ ] Editing `~/.config/hyprmon/config.toml` (opacity / accent / module toggles) updates the panel without restart.
- [ ] `hyprmon --install-agent` creates the LaunchAgent plist and the widget starts after `launchctl bootstrap`.
- [ ] `brew install pipe0919/tap/hyprmon` works on a clean Mac (test in a fresh user account or VM).
- [ ] `gh release view v0.1.0` shows the published release.
- [ ] CI on `main` is green.
