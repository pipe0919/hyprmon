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

public struct ThemePreset: Sendable, Equatable {
    public let id: String      // stable key, e.g. "blue"
    public let label: String   // human label, e.g. "Blue"
    public let hex: String     // e.g. "#7AA2F7"
}

public extension Theme {
    static let presets: [ThemePreset] = [
        .init(id: "blue",   label: "Blue",   hex: "#7AA2F7"),
        .init(id: "pink",   label: "Pink",   hex: "#F7768E"),
        .init(id: "green",  label: "Green",  hex: "#9ECE6A"),
        .init(id: "orange", label: "Orange", hex: "#FF9E64"),
        .init(id: "purple", label: "Purple", hex: "#BB9AF7"),
        .init(id: "cyan",   label: "Cyan",   hex: "#7DCFFF"),
    ]
}
