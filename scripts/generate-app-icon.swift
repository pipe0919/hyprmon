#!/usr/bin/env swift
import AppKit
import CoreGraphics

let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "AppIcon-1024.png"
let size = CGFloat(1024)

let canvas = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // Rounded-rect ("squircle") clip — 224pt radius on 1024 matches macOS app-icon corner.
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let path = CGPath(roundedRect: rect, cornerWidth: 224, cornerHeight: 224, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    // Tokyo-Night-style diagonal gradient from deep indigo to accent blue.
    let colors = [
        NSColor(srgbRed: 0.090, green: 0.118, blue: 0.207, alpha: 1).cgColor,  // #171E35
        NSColor(srgbRed: 0.290, green: 0.392, blue: 0.643, alpha: 1).cgColor,  // #4A64A4
        NSColor(srgbRed: 0.478, green: 0.635, blue: 0.969, alpha: 1).cgColor,  // #7AA2F7 (accent)
    ] as CFArray
    let locations: [CGFloat] = [0.0, 0.6, 1.0]
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: colors,
                              locations: locations)!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: size),
                           end:   CGPoint(x: size, y: 0),
                           options: [])

    // Subtle inner highlight at top-left for depth.
    let highlight = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                               colors: [
                                  NSColor.white.withAlphaComponent(0.20).cgColor,
                                  NSColor.clear.cgColor,
                               ] as CFArray,
                               locations: [0.0, 0.5])!
    ctx.drawRadialGradient(highlight,
                           startCenter: CGPoint(x: size * 0.15, y: size * 0.85),
                           startRadius: 0,
                           endCenter:   CGPoint(x: size * 0.15, y: size * 0.85),
                           endRadius:   size * 0.6,
                           options: [])

    // Brand mark — three rounded bars centered, scaled to 60% of canvas.
    let markCanvas: CGFloat = 22
    let scale = size * 0.55 / markCanvas
    let drawW = markCanvas * scale
    let drawH = markCanvas * scale
    let originX = (size - drawW) / 2
    let originY = (size - drawH) / 2

    // Bars: (x, height) in 22pt space.
    let bars: [(x: CGFloat, h: CGFloat)] = [(6, 8), (10.5, 14), (15, 11)]
    let barWidth: CGFloat = 3
    let radius: CGFloat = 1

    // White with slight gradient for the bars (subtle depth).
    for bar in bars {
        let scaledX = originX + bar.x * scale
        let scaledY = originY + 5 * scale
        let scaledW = barWidth * scale
        let scaledH = bar.h * scale
        let barRect = CGRect(x: scaledX, y: scaledY, width: scaledW, height: scaledH)
        let barPath = CGPath(roundedRect: barRect, cornerWidth: radius * scale, cornerHeight: radius * scale, transform: nil)

        ctx.saveGState()
        ctx.addPath(barPath)
        ctx.clip()
        let barGrad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                 colors: [
                                    NSColor.white.cgColor,
                                    NSColor(white: 0.85, alpha: 1).cgColor,
                                 ] as CFArray,
                                 locations: [0.0, 1.0])!
        ctx.drawLinearGradient(barGrad,
                               start: CGPoint(x: scaledX, y: scaledY + scaledH),
                               end:   CGPoint(x: scaledX, y: scaledY),
                               options: [])
        ctx.restoreGState()
    }
    return true
}

guard let tiff = canvas.tiffRepresentation,
      let rep  = NSBitmapImageRep(data: tiff),
      let png  = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}

let url = URL(fileURLWithPath: outPath)
do {
    try png.write(to: url)
    print("Wrote \(outPath)")
} catch {
    FileHandle.standardError.write("write failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
