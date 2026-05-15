#!/usr/bin/env swift
import AppKit
import CoreGraphics
import CoreText

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "hyprmon-promo.png"
let W: CGFloat = 1200
let H: CGFloat = 630

let canvas = NSImage(size: NSSize(width: W, height: H), flipped: false) { _ in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // ---------- Background: deep diagonal gradient ----------
    let bgColors = [
        NSColor(srgbRed: 0.063, green: 0.075, blue: 0.149, alpha: 1).cgColor, // #101326
        NSColor(srgbRed: 0.106, green: 0.149, blue: 0.255, alpha: 1).cgColor, // #1B2641
        NSColor(srgbRed: 0.180, green: 0.243, blue: 0.435, alpha: 1).cgColor, // #2E3E6F
    ] as CFArray
    let bg = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                        colors: bgColors,
                        locations: [0.0, 0.55, 1.0])!
    ctx.drawLinearGradient(bg,
                           start: CGPoint(x: 0, y: H),
                           end:   CGPoint(x: W, y: 0),
                           options: [])

    // ---------- Subtle radial highlight top-left ----------
    let hl = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                        colors: [
                            NSColor(srgbRed: 0.478, green: 0.635, blue: 0.969, alpha: 0.18).cgColor,
                            NSColor.clear.cgColor,
                        ] as CFArray,
                        locations: [0.0, 1.0])!
    ctx.drawRadialGradient(hl,
                           startCenter: CGPoint(x: 200, y: H - 100),
                           startRadius: 0,
                           endCenter:   CGPoint(x: 200, y: H - 100),
                           endRadius:   500,
                           options: [])

    // ---------- Brand mark (3 bars) on the left ----------
    // Brand mark is in a 22-pt canvas; we scale it up and center vertically in the left third.
    let markBoxX: CGFloat = 90
    let markBoxY: CGFloat = (H - 380) / 2
    let markScale: CGFloat = 380.0 / 22.0

    let bars: [(x: CGFloat, h: CGFloat)] = [(6, 8), (10.5, 14), (15, 11)]
    for bar in bars {
        let rx = markBoxX + bar.x * markScale
        let ry = markBoxY + 5 * markScale
        let rw = 3 * markScale
        let rh = bar.h * markScale
        let rect = CGRect(x: rx, y: ry, width: rw, height: rh)
        let path = CGPath(roundedRect: rect, cornerWidth: 1 * markScale, cornerHeight: 1 * markScale, transform: nil)

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [
                                NSColor.white.cgColor,
                                NSColor(srgbRed: 0.478, green: 0.635, blue: 0.969, alpha: 1).cgColor,
                              ] as CFArray,
                              locations: [0.0, 1.0])!
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: rx, y: ry + rh),
                               end:   CGPoint(x: rx, y: ry),
                               options: [])
        ctx.restoreGState()
    }

    // ---------- Text helpers ----------
    func draw(text: String,
              at point: CGPoint,
              size: CGFloat,
              weight: NSFont.Weight,
              color: NSColor,
              tracking: CGFloat = 0,
              design: NSFontDescriptor.SystemDesign = .default) {
        let baseFont = NSFont.systemFont(ofSize: size, weight: weight)
        let descriptor = baseFont.fontDescriptor.withDesign(design) ?? baseFont.fontDescriptor
        let font = NSFont(descriptor: descriptor, size: size) ?? baseFont
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .kern: tracking,
        ]
        let attr = NSAttributedString(string: text, attributes: attrs)
        attr.draw(at: point)
    }

    // ---------- Right side: title, tagline, install ----------
    let rightX: CGFloat = 540

    draw(text: "hyprmon",
         at: CGPoint(x: rightX, y: H - 200),
         size: 96,
         weight: .heavy,
         color: .white,
         tracking: -2)

    draw(text: "macOS menubar widget",
         at: CGPoint(x: rightX, y: H - 250),
         size: 26,
         weight: .medium,
         color: NSColor(srgbRed: 0.478, green: 0.635, blue: 0.969, alpha: 1),
         tracking: 1)

    // Feature lines
    let featureColor = NSColor(white: 0.92, alpha: 1)
    let features = [
        "CPU · RAM · Battery in real time",
        "Top processes by CPU / RAM / Energy",
        "Live Claude Code usage from the OAuth API",
    ]
    var fy: CGFloat = H - 330
    for f in features {
        draw(text: "•  \(f)",
             at: CGPoint(x: rightX, y: fy),
             size: 22,
             weight: .regular,
             color: featureColor)
        fy -= 38
    }

    // Install command (monospaced)
    draw(text: "brew install pipe0919/tap/hyprmon",
         at: CGPoint(x: rightX, y: 70),
         size: 22,
         weight: .medium,
         color: NSColor(white: 0.97, alpha: 1),
         design: .monospaced)

    // Repo URL (small, muted)
    draw(text: "github.com/pipe0919/hyprmon  ·  open-source · Apache 2.0",
         at: CGPoint(x: rightX, y: 40),
         size: 15,
         weight: .regular,
         color: NSColor(white: 0.65, alpha: 1))

    return true
}

guard let tiff = canvas.tiffRepresentation,
      let rep  = NSBitmapImageRep(data: tiff),
      let png  = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outPath))
    print("Wrote \(outPath)")
} catch {
    FileHandle.standardError.write("write failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
