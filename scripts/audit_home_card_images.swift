#!/usr/bin/env swift
import Foundation
import ImageIO
import CoreGraphics

// Read-only inspection of the actual decoded pixels, not merely PNG alpha metadata.
var results: [[String: Any]] = []
for path in CommandLine.arguments.dropFirst() {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
    let width = image.width, height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    var bounds = [width, height, -1, -1]
    var transparent = 0
    pixels.withUnsafeMutableBytes { bytes in
        guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        for y in 0..<height {
            for x in 0..<width {
                let alpha = bytes[(y * width + x) * 4 + 3]
                if alpha == 0 { transparent += 1 }
                if alpha > 16 {
                    bounds[0] = min(bounds[0], x); bounds[1] = min(bounds[1], y)
                    bounds[2] = max(bounds[2], x); bounds[3] = max(bounds[3], y)
                }
            }
        }
    }
    results.append(["path": path, "pixels": [width, height], "transparentPixelFraction": Double(transparent) / Double(width * height), "visibleBounds": bounds])
}
let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
