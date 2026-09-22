#!/usr/bin/env swift
// Renders the app icon with the real New York serif (the system serif on macOS),
// so the icon matches the wordmark in the app exactly.
//
//   swift tools/render-icon.swift
//
// Writes icon-1024.png, icon-1024-dark.png and icon-1024-tinted.png into the
// asset catalog. The committed PNGs were drawn with a stand-in serif on Linux;
// run this once on a Mac before a build you care about.
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let out = root.appendingPathComponent("HairDone/Resources/Assets.xcassets/AppIcon.appiconset")
let S: CGFloat = 1024

func rgb(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func serifItalic(_ size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .medium)
    let desc = base.fontDescriptor.withDesign(.serif)?.withSymbolicTraits(.italic) ?? base.fontDescriptor
    return NSFont(descriptor: desc, size: size) ?? base
}

func render(bg: NSColor?, ink: NSColor, lacquer: NSColor, to file: String) {
    // A fixed 1024 px bitmap, not NSImage.lockFocus, which renders at the screen's scale
    // (2048 px on a Retina Mac) and then fails "did not have any applicable content".
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { fatalError("bitmap") }
    rep.size = NSSize(width: S, height: S)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    if let bg { bg.setFill(); NSRect(x: 0, y: 0, width: S, height: S).fill() }
    let font = serifItalic(S * 0.31)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
    let lines = ["hd", "nd"]
    let lineH = S * 0.31 * 0.98
    let widths = lines.map { (NSAttributedString(string: $0, attributes: attrs).size().width) }
    let blockW = (widths.max() ?? 0) + S * 0.13
    let x0 = (S - blockW) / 2
    // AppKit's origin is bottom-left; lay the first line at the top.
    var top = S / 2 + lineH
    for (i, text) in lines.enumerated() {
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        let y = top - lineH + (lineH - size.height) / 2
        str.draw(at: NSPoint(x: x0, y: y))
        // The full stop sits on the baseline, just after the d.
        let r = S * 0.031
        let baseline = y + font.descender.magnitude
        let dot = NSRect(x: x0 + widths[i] + S * 0.062 - r, y: baseline - r * 0.15, width: r * 2, height: r * 2)
        lacquer.setFill(); NSBezierPath(ovalIn: dot).fill()
        top -= lineH
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("could not encode \(file)") }
    try! png.write(to: out.appendingPathComponent(file))
    print("wrote \(file) (\(rep.pixelsWide) px)")
}

render(bg: rgb(0xF8F3EC), ink: rgb(0x241A16), lacquer: rgb(0xC8323A), to: "icon-1024.png")
render(bg: rgb(0x171210), ink: rgb(0xF4ECE4), lacquer: rgb(0xE2504F), to: "icon-1024-dark.png")
render(bg: nil, ink: .white, lacquer: .white, to: "icon-1024-tinted.png")
