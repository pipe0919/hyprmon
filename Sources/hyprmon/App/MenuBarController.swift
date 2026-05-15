import AppKit
import SwiftUI
import HyprmonCore

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()

    private let system: SystemSampler
    private let claude: ClaudeMonitor
    private var cfg: Config
    private var theme: Theme
    private var hosting: NSHostingController<ContentView>
    private let configPath: String

    init(system: SystemSampler,
         claude: ClaudeMonitor,
         cfg: Config,
         theme: Theme,
         configPath: String) {
        self.system = system
        self.claude = claude
        self.cfg = cfg
        self.theme = theme
        self.configPath = configPath

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let initialContent = ContentView(system: system, claude: claude, cfg: cfg, theme: theme)
        self.hosting = NSHostingController(rootView: initialContent)

        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "hyprmon")
            button.image?.isTemplate = true
            button.action = #selector(buttonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hosting
    }

    func updateConfig(_ newCfg: Config, theme: Theme) {
        self.cfg = newCfg
        self.theme = theme
        hosting.rootView = ContentView(system: system, claude: claude, cfg: newCfg, theme: theme)
    }

    @objc private func buttonClicked(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
            return
        }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Context menu

    private func showContextMenu() {
        let menu = NSMenu()

        let header = NSMenuItem(title: "hyprmon \(versionString())", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        // Theme submenu
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        for preset in Theme.presets {
            let item = NSMenuItem(title: preset.label, action: #selector(pickTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.hex
            if preset.hex.lowercased() == cfg.accentHex.lowercased() {
                item.state = .on
            }
            themeMenu.addItem(item)
        }
        themeMenu.addItem(.separator())
        let custom = NSMenuItem(title: "Custom (edit config…)", action: #selector(openConfig), keyEquivalent: "")
        custom.target = self
        themeMenu.addItem(custom)
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        // Launch at Login toggle
        let launch = NSMenuItem(title: "Launch at Login",
                                action: #selector(toggleLaunchAtLogin),
                                keyEquivalent: "")
        launch.target = self
        launch.state = LaunchAgent.isInstalled ? .on : .off
        menu.addItem(launch)

        menu.addItem(.separator())

        let openCfg = NSMenuItem(title: "Open config file…", action: #selector(openConfig), keyEquivalent: "")
        openCfg.target = self
        menu.addItem(openCfg)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit hyprmon", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
    }

    private func versionString() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    // MARK: - Menu actions

    @objc private func pickTheme(_ sender: NSMenuItem) {
        guard let hex = sender.representedObject as? String else { return }
        do {
            try updateConfigAccent(to: hex)
        } catch {
            NSLog("hyprmon: failed to write theme to config: \(error)")
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if LaunchAgent.isInstalled {
                try LaunchAgent.uninstall()
            } else {
                try LaunchAgent.install()
            }
        } catch {
            NSLog("hyprmon: launch-at-login toggle failed: \(error)")
        }
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Config writing

    /// Rewrites the `accent = "..."` line in config.toml (or appends one if missing).
    /// FSEvents picks it up and the loader triggers onChange.
    private func updateConfigAccent(to hex: String) throws {
        let path = configPath
        var contents = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        let pattern = #"^(\s*accent\s*=\s*).*$"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)
        let replacement = "$1\"\(hex)\""
        if regex.firstMatch(in: contents, options: [], range: range) != nil {
            contents = regex.stringByReplacingMatches(in: contents, options: [], range: range, withTemplate: replacement)
        } else {
            if !contents.isEmpty && !contents.hasSuffix("\n") { contents += "\n" }
            contents += "accent = \"\(hex)\"\n"
        }
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
