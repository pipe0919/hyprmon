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
