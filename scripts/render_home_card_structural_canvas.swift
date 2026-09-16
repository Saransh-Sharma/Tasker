import AppKit

// Deterministic presentation of an unmodified native capture on a contrasting
// matte. This is generation input, never a generated reference or runtime asset.
guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: render_home_card_structural_canvas INPUT OUTPUT")
}
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = NSImage(contentsOf: sourceURL),
      let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil),
      cgImage.width == 682, cgImage.height == 1907,
      let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2048,
          pixelsHigh: 2048, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
          isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Expected a 682 by 1907 native PNG and valid bitmap context")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
NSColor(srgbRed: 0, green: 0.75, blue: 0.75, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2048, height: 2048)).fill()
graphics.imageInterpolation = .none
graphics.cgContext.draw(cgImage, in: CGRect(x: 683, y: 2048 - 70 - 1907, width: 682, height: 1907))
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode canvas")
}
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: outputURL, options: .atomic)
