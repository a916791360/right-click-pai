import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = 1024

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to create icon bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let tileRect = NSRect(x: 96, y: 96, width: 832, height: 832)
let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: 190, yRadius: 190)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowBlurRadius = 42
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.set()
NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
tilePath.fill()

NSGraphicsContext.current?.saveGraphicsState()
NSShadow().set()

let accentPath = NSBezierPath(roundedRect: NSRect(x: 146, y: 146, width: 732, height: 732), xRadius: 150, yRadius: 150)
accentPath.lineWidth = 14
NSColor(calibratedRed: 0.08, green: 0.72, blue: 0.88, alpha: 1).setStroke()
accentPath.stroke()

let configuration = NSImage.SymbolConfiguration(pointSize: 440, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [
        NSColor(calibratedWhite: 0.10, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.72, blue: 0.88, alpha: 1),
        NSColor(calibratedRed: 0.16, green: 0.72, blue: 0.36, alpha: 1)
    ]))

guard let symbol = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "超级右键")?
    .withSymbolConfiguration(configuration) else {
    fatalError("Unable to load SF Symbol")
}

let symbolRect = NSRect(x: 292, y: 274, width: 440, height: 476)
symbol.draw(in: symbolRect)

NSGraphicsContext.current?.restoreGraphicsState()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon")
}
try png.write(to: outputURL)
