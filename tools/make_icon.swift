import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

// Build-time artwork only. Opaque RGB output at exactly 1024 pixels.
let size = 1024
guard let canvas = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                             bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("No canvas") }
canvas.setFillColor(CGColor(red: 0.98, green: 0.977, blue: 0.961, alpha: 1))
canvas.fill(CGRect(x: 0, y: 0, width: size, height: size))
let ink = CGColor(red: 0.19, green: 0.36, blue: 0.55, alpha: 1)
canvas.setStrokeColor(ink)
canvas.setLineWidth(14)
canvas.setLineCap(.round)
for i in 0...3 {
    let p = 200 + CGFloat(i) * 208
    canvas.move(to: CGPoint(x: p, y: 200)); canvas.addLine(to: CGPoint(x: p, y: 824))
    canvas.move(to: CGPoint(x: 200, y: p)); canvas.addLine(to: CGPoint(x: 824, y: p))
    canvas.strokePath()
}
canvas.setFillColor(ink)
for point in [CGPoint(x: 304, y: 304), CGPoint(x: 512, y: 512), CGPoint(x: 720, y: 720)] {
    canvas.fillEllipse(in: CGRect(x: point.x - 25, y: point.y - 25, width: 50, height: 50))
}
let url = URL(fileURLWithPath: "GridZero/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
guard let image = canvas.makeImage(),
      let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("No output") }
CGImageDestinationAddImage(output, image, nil)
guard CGImageDestinationFinalize(output) else { fatalError("Could not write icon") }
print("Rendered GridZero app icon")
