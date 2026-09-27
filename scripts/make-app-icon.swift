// Renders the app icon: swift scripts/make-app-icon.swift HabitTracker/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
import AppKit

let size = 1024
let out = CommandLine.arguments[1]
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// Background: app bg with a faint green lift toward the top.
let bg = CGGradient(colorsSpace: cs, colors: [rgb(0x16201A), rgb(0x0D100E)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])

// 3×3 grid of days: kept (accent), missed (dim), today in progress (outlined).
enum Cell { case kept, missed, today }
let pattern: [Cell] = [.kept, .kept, .missed,
                       .kept, .kept, .kept,
                       .kept, .kept, .today]
let cell: CGFloat = 196, gap: CGFloat = 40, radius: CGFloat = 46
let grid = cell * 3 + gap * 2
let origin = (CGFloat(size) - grid) / 2

for (i, kind) in pattern.enumerated() {
    let row = CGFloat(i / 3), col = CGFloat(i % 3)
    // CoreGraphics origin is bottom-left; draw rows top-down.
    let rect = CGRect(x: origin + col * (cell + gap), y: origin + (2 - row) * (cell + gap), width: cell, height: cell)
    switch kind {
    case .kept:
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.setFillColor(rgb(0x58C98C)); ctx.fillPath()
    case .missed:
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.setFillColor(rgb(0x1C3527)); ctx.fillPath()
    case .today:
        let lw: CGFloat = 16
        let inset = rect.insetBy(dx: lw / 2, dy: lw / 2)
        ctx.addPath(CGPath(roundedRect: inset, cornerWidth: radius - lw / 2, cornerHeight: radius - lw / 2, transform: nil))
        ctx.setFillColor(rgb(0x132018)); ctx.fillPath()
        ctx.addPath(CGPath(roundedRect: inset, cornerWidth: radius - lw / 2, cornerHeight: radius - lw / 2, transform: nil))
        ctx.setStrokeColor(rgb(0x58C98C)); ctx.setLineWidth(lw); ctx.strokePath()
    }
}

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
