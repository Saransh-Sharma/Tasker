import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
let sourceURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let width = Int(arguments[3])!, height = Int(arguments[4])!
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Invalid source") }
let scale = min(CGFloat(width) / CGFloat(image.width), CGFloat(height) / CGFloat(image.height))
let target = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
target.interpolationQuality = .high
target.draw(image, in: CGRect(x: (CGFloat(width) - CGFloat(image.width) * scale) / 2,
    y: (CGFloat(height) - CGFloat(image.height) * scale) / 2,
    width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale))
let result = target.makeImage()!
let bytes = target.data!.assumingMemoryBound(to: UInt8.self)
var transparent = 0
var painted = 0
for i in 0..<(width * height) {
    if bytes[i * 4 + 3] == 0 { transparent += 1 }
    if bytes[i * 4 + 3] > 16 { painted += 1 }
}
guard transparent > 0, painted > 0 else { fatalError("Expected genuine transparent artwork") }
let output = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(output, result, nil)
guard CGImageDestinationFinalize(output) else { fatalError("Export failed") }
let audit: [String: Any] = ["source_pixels": [image.width, image.height], "export_pixels": [width, height],
    "transparent_fraction": Double(transparent) / Double(width * height), "painted_fraction": Double(painted) / Double(width * height)]
print(String(data: try! JSONSerialization.data(withJSONObject: audit, options: [.sortedKeys]), encoding: .utf8)!)
