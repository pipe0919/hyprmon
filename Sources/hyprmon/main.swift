import AppKit
import SwiftUI
import HyprmonCore

let VERSION = "0.4.0"

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

let configDir = (configPath as NSString).deletingLastPathComponent
try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
if !FileManager.default.fileExists(atPath: configPath) {
    let defaults = """
    # ~/.config/hyprmon/config.toml — auto-generated defaults
    accent       = "#7AA2F7"
    refresh_ms   = 1000
    claude_refresh_ms = 60000

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
    show_5h     = true
    show_weekly = true
    """
    try? defaults.write(toFile: configPath, atomically: true, encoding: .utf8)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

@MainActor final class Holder {
    var controller: MenuBarController?
    let system = SystemSampler()
    let claude = ClaudeMonitor()
    let loader: ConfigLoader
    var cfg: Config
    init(loader: ConfigLoader) {
        self.loader = loader
        self.cfg = loader.config
    }
}

let nonactorLoader = try ConfigLoader(path: configPath)

@MainActor
func runApp(loader: ConfigLoader) {
    let holder = Holder(loader: loader)

    func makeTheme(_ cfg: Config) -> Theme {
        Theme(
            accent: Color(hexString: cfg.accentHex) ?? Theme.default.accent,
            opacity: cfg.opacity
        )
    }

    func mapSort(_ s: Config.ProcessSort) -> ProcessSampler.SortKey {
        switch s {
        case .cpu:    return .cpu
        case .ram:    return .ram
        case .energy: return .energy
        }
    }

    let theme = makeTheme(holder.cfg)
    let controller = MenuBarController(system: holder.system, claude: holder.claude, cfg: holder.cfg, theme: theme, configPath: loader.path)

    // Auto-install LaunchAgent on first run so the widget starts at login by default.
    // The user can opt out from the right-click menu.
    if !LaunchAgent.isInstalled {
        try? LaunchAgent.install()
    }
    holder.controller = controller

    loader.onChange = { newCfg in
        Task { @MainActor in
            holder.cfg = newCfg
            holder.system.start(intervalMs: newCfg.refreshMs, processCount: newCfg.processes.count, sortBy: mapSort(newCfg.processes.sortBy))
            holder.claude.start(intervalMs: newCfg.claudeRefreshMs)
            controller.updateConfig(newCfg, theme: makeTheme(newCfg))
        }
    }
    loader.startWatching()

    holder.system.start(intervalMs: holder.cfg.refreshMs, processCount: holder.cfg.processes.count, sortBy: mapSort(holder.cfg.processes.sortBy))
    holder.claude.start(intervalMs: holder.cfg.claudeRefreshMs)
}

Task { @MainActor in
    runApp(loader: nonactorLoader)
}

app.run()
