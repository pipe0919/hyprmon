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

    init(system: SystemSampler, claude: ClaudeMonitor, cfg: Config, theme: Theme) {
        self.system = system
        self.claude = claude
        self.cfg = cfg
        self.theme = theme

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

    private func showContextMenu() {
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit hyprmon", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Detach so the next left-click triggers buttonClicked, not the menu.
        DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
