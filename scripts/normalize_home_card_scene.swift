import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

// Aspect-preserving export into the prompt's exact safe rectangle. Originals stay intact.
let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]
let runtimeEdge = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3]) : nil
guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: input) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Invalid image") }
let width = image.width, height = image.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
var bounds = [width, height, -1, -1]
pixels.withUnsafeMutableBytes { bytes in
    let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    for y in 0..<height {
        for x in 0..<width where bytes[(y * width + x) * 4 + 3] > (runtimeEdge == nil ? 0 : 16) {
            bounds[0] = min(bounds[0], x); bounds[1] = min(bounds[1], y)
            bounds[2] = max(bounds[2], x); bounds[3] = max(bounds[3], y)
        }
    }
}
guard bounds[2] >= 0 else { fatalError("Empty illustration") }
let visibleWidth = CGFloat(bounds[2] - bounds[0] + 1)
let visibleHeight = CGFloat(bounds[3] - bounds[1] + 1)
if let runtimeEdge {
    // Runtime exports remove the canonical canvas's reading field, with a
    // 24-source-pixel guard around visible paint. The canonical source is unchanged.
    let cropWidth = visibleWidth + 48
    let cropHeight = visibleHeight + 48
    let ratio = CGFloat(runtimeEdge) / max(cropWidth, cropHeight)
    let outputWidth = Int(ceil(cropWidth * ratio))
    let outputHeight = Int(ceil(cropHeight * ratio))
    let target = CGContext(data: nil, width: outputWidth, height: outputHeight, bitsPerComponent: 8,
        bytesPerRow: outputWidth * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    target.interpolationQuality = .high
    target.draw(image, in: CGRect(x: (24-CGFloat(bounds[0]))*ratio,
        y: (24-CGFloat(bounds[1]))*ratio, width: CGFloat(width)*ratio, height: CGFloat(height)*ratio))
    let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL,
        UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, target.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not export runtime crop") }
    exit(0)
}
let scale = min(576 / visibleWidth, 768 / visibleHeight)
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.interpolationQuality = .high
// Center the visible bounds inside x=384...960, y=128...896.
context.draw(image, in: CGRect(x: 384 + (576-visibleWidth*scale)/2-CGFloat(bounds[0])*scale,
    y: 128 + (768-visibleHeight*scale)/2-CGFloat(bounds[1])*scale,
    width: CGFloat(width)*scale, height: CGFloat(height)*scale))
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not export") }
