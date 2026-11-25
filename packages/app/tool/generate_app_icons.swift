// Run on macOS: swift packages/app/tool/generate_app_icons.swift
// Geometry mirrors PsMark in lib/design/components/identity.dart;
// colors mirror PsPalette.light in lib/design/tokens.dart.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let app = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
let android = app.appendingPathComponent("android/app/src/main/res")
let ios = app.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
let background = "F4EFE6"
let marks: [(color: String, points: [(Double, Double)])] = [
    ("1C1814", [(12, 12), (36, 12), (36, 19), (19, 19), (19, 38), (12, 38)]),
    ("B4361C", [(52, 52), (28, 52), (28, 45), (45, 45), (45, 26), (52, 26)]),
]

func write(_ text: String, to file: URL) throws {
    try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try (text + "\n").write(to: file, atomically: true, encoding: .utf8)
}

func color(_ hex: String) -> CGColor {
    let rgb = UInt32(hex, radix: 16)!
    return CGColor(
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        components: [CGFloat((rgb >> 16) & 255) / 255,
                     CGFloat((rgb >> 8) & 255) / 255,
                     CGFloat(rgb & 255) / 255, 1])!
}

func png(size: Int, to file: URL) throws {
    // Opaque RGB keeps the iOS catalog suitable for App Store distribution.
    let canvas = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    canvas.translateBy(x: 0, y: CGFloat(size))
    canvas.scaleBy(x: CGFloat(size) / 64, y: -CGFloat(size) / 64)
    canvas.setFillColor(color(background))
    canvas.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
    for mark in marks {
        let path = CGMutablePath()
        path.addLines(between: mark.points.map { CGPoint(x: $0.0, y: $0.1) })
        path.closeSubpath()
        canvas.addPath(path)
        canvas.setFillColor(color(mark.color))
        canvas.fillPath()
    }
    try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(
        file as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, canvas.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

let polygons = marks.map { mark in
    let points = mark.points.map { "\(Int($0.0)),\(Int($0.1))" }.joined(separator: " ")
    return "  <polygon fill=\"#\(mark.color)\" points=\"\(points)\"/>"
}.joined(separator: "\n")
try write("""
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="1024" height="1024">
  <title>pagestage</title>
  <rect width="64" height="64" fill="#\(background)"/>
\(polygons)
</svg>
""", to: app.appendingPathComponent("assets/branding/app_icon.svg"))

let densities = [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                 ("xxhdpi", 144), ("xxxhdpi", 192)]
for (density, size) in densities {
    try png(size: size, to: android.appendingPathComponent("mipmap-\(density)/ic_launcher.png"))
}

// The 48 dp mark sits at the center of the adaptive icon's 108 dp layers.
let paths = marks.map { mark in
    let points = mark.points.map { "\(Int($0.0)),\(Int($0.1))" }.joined(separator: " L")
    return "        <path android:fillColor=\"#\(mark.color)\" android:pathData=\"M\(points) Z\"/>"
}.joined(separator: "\n")
try write("""
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <group android:scaleX="1.2" android:scaleY="1.2"
        android:translateX="15.6" android:translateY="15.6">
\(paths)
    </group>
</vector>
""", to: android.appendingPathComponent("drawable/ic_launcher_foreground.xml"))
try write("""
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#\(background)</color>
</resources>
""", to: android.appendingPathComponent("values/icon_colors.xml"))
try write("""
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
""", to: android.appendingPathComponent("mipmap-anydpi-v26/ic_launcher.xml"))

struct Catalog: Decodable {
    struct Icon: Decodable {
        let filename: String
        let size: String
        let scale: String
    }
    let images: [Icon]
}
let catalog = try JSONDecoder().decode(
    Catalog.self, from: Data(contentsOf: ios.appendingPathComponent("Contents.json")))
var written = Set<String>()
for icon in catalog.images where written.insert(icon.filename).inserted {
    let points = Double(icon.size.split(separator: "x")[0])!
    let scale = Double(icon.scale.dropLast())!
    try png(size: Int(points * scale), to: ios.appendingPathComponent(icon.filename))
}
print("Generated \(densities.count) Android and \(written.count) iOS PNGs, adaptive icon layers, and SVG.")
