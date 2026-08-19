//
//  make-icon.swift
//  daily_log
//
//  Draws the Daily logo and writes every asset the app needs:
//  the AppIcon PNGs and the monochrome menu-bar template.
//
//  Run from the repo root:   swift Tools/make-icon.swift
//
//  The mark is a day dial — an open ring with a filled wedge inside it,
//  the wedge being the part of the day that's been logged. Everything is
//  expressed as a fraction of the plate, so it holds up from 1024 down to 16.
//

import AppKit

// MARK: - Geometry

/// A superellipse, which is what Apple's rounded-rect corners actually are.
/// `n = 5` lands close enough to the macOS icon plate that nothing looks off
/// next to it in the Dock.
func squircle(in rect: CGRect, n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let (a, b) = (rect.width / 2, rect.height / 2)
    let steps = 1440
    for step in 0...steps {
        let t = CGFloat(step) / CGFloat(steps) * 2 * .pi
        let (ct, st) = (cos(t), sin(t))
        let x = rect.midX + a * pow(abs(ct), 2 / n) * (ct < 0 ? -1 : 1)
        let y = rect.midY + b * pow(abs(st), 2 / n) * (st < 0 ? -1 : 1)
        step == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

/// The wedge starts at 12 o'clock and sweeps clockwise.
let loggedFraction: CGFloat = 0.66

/// Ring and wedge, as fractions of the plate's side.
enum Dial {
    static let ringOuterRadius: CGFloat = 0.325
    static let ringWidth: CGFloat = 0.075
    static let gap: CGFloat = 0.055

    /// The menu bar sits next to system glyphs drawn from solid shapes, so the
    /// ring needs a little more weight there to carry the same visual mass.
    static let menuBarRingWidth: CGFloat = 0.09
}

/// Draws the dial centred in `plate`, using whatever colours are already set.
func drawDial(in context: CGContext, plate: CGRect, ringWidth: CGFloat = Dial.ringWidth) {
    let side = plate.width
    let centre = CGPoint(x: plate.midX, y: plate.midY)
    let strokeRadius = Dial.ringOuterRadius - ringWidth / 2
    let wedgeRadius = strokeRadius - ringWidth / 2 - Dial.gap

    context.setLineWidth(ringWidth * side)
    context.addArc(center: centre, radius: strokeRadius * side,
                   startAngle: 0, endAngle: 2 * .pi, clockwise: false)
    context.strokePath()

    let top = CGFloat.pi / 2
    context.move(to: centre)
    context.addArc(center: centre, radius: wedgeRadius * side,
                   startAngle: top, endAngle: top - 2 * .pi * loggedFraction,
                   clockwise: true)
    context.closePath()
    context.fillPath()
}

// MARK: - The app icon

func drawAppIcon(in context: CGContext, size: CGFloat) {
    // macOS plates sit inset in their canvas, with room for the shadow.
    let inset = size * 0.1
    let plate = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let path = squircle(in: plate)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -size * 0.012),
                      blur: size * 0.03,
                      color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.28))
    context.addPath(path)
    context.setFillColor(CGColor(srgbRed: 0.18, green: 0.39, blue: 0.87, alpha: 1))
    context.fillPath()
    context.restoreGState()

    // Blue plate, lighter at the top.
    context.saveGState()
    context.addPath(path)
    context.clip()
    let plateGradient = CGGradient(
        colorsSpace: space,
        colors: [CGColor(srgbRed: 0.42, green: 0.63, blue: 0.99, alpha: 1),
                 CGColor(srgbRed: 0.15, green: 0.35, blue: 0.85, alpha: 1)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(plateGradient,
                               start: CGPoint(x: 0, y: plate.maxY),
                               end: CGPoint(x: 0, y: plate.minY),
                               options: [])

    // A soft sheen across the top third, so the plate doesn't read as flat.
    let sheen = CGGradient(
        colorsSpace: space,
        colors: [CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.22),
                 CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(sheen,
                               start: CGPoint(x: 0, y: plate.maxY),
                               end: CGPoint(x: 0, y: plate.midY),
                               options: [])
    context.restoreGState()

    // Hairline rim, which is what keeps the icon crisp on a dark Dock.
    context.saveGState()
    context.addPath(path)
    context.setLineWidth(max(1, size * 0.004))
    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.28))
    context.strokePath()
    context.restoreGState()

    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.92))
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    drawDial(in: context, plate: plate)
}

// MARK: - The menu-bar template

/// Pure black with alpha. AppKit recolours it for light, dark and highlighted bars.
func drawMenuBarIcon(in context: CGContext, size: CGFloat) {
    let black = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
    context.setStrokeColor(black)
    context.setFillColor(black)
    // The glyph fills its box; the menu bar supplies the padding.
    let plate = CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: -size * 0.19,
                                                                     dy: -size * 0.19)
    drawDial(in: context, plate: plate, ringWidth: Dial.menuBarRingWidth)
}

// MARK: - Rasterising

func png(pixels: Int, _ draw: (CGContext, CGFloat) -> Void) -> Data {
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high
    draw(context, CGFloat(pixels))

    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    rep.size = NSSize(width: pixels, height: pixels)
    return rep.representation(using: .png, properties: [:])!
}

// MARK: - Writing the asset catalogue

let assets = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("daily_log/Assets.xcassets")

guard FileManager.default.fileExists(atPath: assets.path) else {
    FileHandle.standardError.write(Data("Run this from the repo root.\n".utf8))
    exit(1)
}

func write(_ data: Data, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                           withIntermediateDirectories: true)
    try data.write(to: url)
    print("  \(url.lastPathComponent)")
}

// AppIcon: every point size macOS asks for, at 1x and 2x.
let appIcon = assets.appendingPathComponent("AppIcon.appiconset")
var appIconEntries: [String] = []

print("AppIcon.appiconset")
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try write(png(pixels: pixels, drawAppIcon), to: appIcon.appendingPathComponent(name))
        appIconEntries.append("""
                {
                  "filename" : "\(name)",
                  "idiom" : "mac",
                  "scale" : "\(scale)x",
                  "size" : "\(points)x\(points)"
                }
            """)
    }
}

try write(Data("""
{
  "images" : [
\(appIconEntries.joined(separator: ",\n"))
  ],
  "info" : {
    "author" : "make-icon.swift",
    "version" : 1
  }
}

""".utf8), to: appIcon.appendingPathComponent("Contents.json"))

// MenuBarIcon: an 18pt template, the size AppKit wants in the status bar.
let menuBar = assets.appendingPathComponent("MenuBarIcon.imageset")
var menuBarEntries: [String] = []

print("MenuBarIcon.imageset")
for scale in [1, 2] {
    let name = "menubar\(scale == 2 ? "@2x" : "").png"
    try write(png(pixels: 18 * scale, drawMenuBarIcon), to: menuBar.appendingPathComponent(name))
    menuBarEntries.append("""
            {
              "filename" : "\(name)",
              "idiom" : "universal",
              "scale" : "\(scale)x"
            }
        """)
}

try write(Data("""
{
  "images" : [
\(menuBarEntries.joined(separator: ",\n"))
  ],
  "info" : {
    "author" : "make-icon.swift",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}

""".utf8), to: menuBar.appendingPathComponent("Contents.json"))
