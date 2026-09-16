import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// All rectangles use top-left image coordinates. Intentional canvas padding is
// removed first; only subsequent aspect correction counts against the 4% limit.
struct Specification: Decodable {
    let requested_canvas_pixels: [Double]
    let card_rect_pixels: [Double]
    let final_export_pixels: [Int]
    let appearance: String
}
func reject(_ reason: String) -> Never {
    fputs(reason + "\n", stderr)
    exit(2)
}
let args = CommandLine.arguments
guard args.count == 5 else { reject("Usage: exporter source.png export.png specification.json transform.json") }
let spec = try JSONDecoder().decode(Specification.self, from: Data(contentsOf: URL(fileURLWithPath: args[3])))
guard spec.requested_canvas_pixels.count == 2, spec.card_rect_pixels.count == 4,
      spec.final_export_pixels.count == 2 else { reject("Invalid dimension field lengths") }
let canvas = spec.requested_canvas_pixels, rect = spec.card_rect_pixels
let width = spec.final_export_pixels[0], height = spec.final_export_pixels[1]
guard canvas.allSatisfy({ $0.isFinite && $0 > 0 }), rect.allSatisfy({ $0.isFinite }),
      width > 0, height > 0, rect[0] >= 0, rect[1] >= 0, rect[2] > 0, rect[3] > 0,
      rect[0] + rect[2] <= canvas[0], rect[1] + rect[3] <= canvas[1] else { reject("Card rectangle outside requested canvas") }
guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { reject("Invalid source image") }
// Uniform fit anchors the requested canvas in the actual output. Differing
// aspect ratios cannot be mapped using separate x/y scales without stretching.
let canvasScale = min(Double(image.width) / canvas[0], Double(image.height) / canvas[1])
let canvasOrigin = [(Double(image.width) - canvas[0] * canvasScale) / 2,
                    (Double(image.height) - canvas[1] * canvasScale) / 2]
let aspectCorrection = 1 - (canvas[0] * canvas[1] * canvasScale * canvasScale) / Double(image.width * image.height)
guard aspectCorrection <= 0.04 else { reject("Actual canvas aspect requires more than 4% unintended correction; regenerate") }
let mapped = CGRect(x: canvasOrigin[0] + rect[0] * canvasScale, y: canvasOrigin[1] + rect[1] * canvasScale,
                    width: rect[2] * canvasScale, height: rect[3] * canvasScale)
// Integral rounding is recorded; proportional drawing below avoids distortion.
guard let card = image.cropping(to: mapped.integral) else { reject("Unable to crop card rectangle") }
let scale = max(Double(width) / Double(card.width), Double(height) / Double(card.height))
let cardCorrection = max(0, 1 - Double(width * height) / (Double(card.width * card.height) * scale * scale))
let combinedCorrection = 1 - (1 - aspectCorrection) * (1 - cardCorrection)
guard combinedCorrection <= 0.04 else { reject("Card export requires more than 4% unintended correction; regenerate") }
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let dark = spec.appearance == "dark"
context.setFillColor(CGColor(red: dark ? 40/255 : 251/255, green: dark ? 42/255 : 243/255, blue: dark ? 68/255 : 226/255, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
context.interpolationQuality = .high
context.draw(card, in: CGRect(x: (Double(width) - Double(card.width) * scale) / 2,
    y: (Double(height) - Double(card.height) * scale) / 2, width: Double(card.width) * scale, height: Double(card.height) * scale))
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { reject("Export failed") }
let transform: [String: Any] = [
    "coordinate_system": "top-left pixels", "actual_canvas_pixels": [image.width, image.height],
    "requested_canvas_pixels": canvas, "requested_card_rect_pixels": rect,
    "canvas_uniform_scale": canvasScale, "canvas_origin_in_actual_pixels": canvasOrigin,
    "actual_card_rect_pixels": [mapped.minX, mapped.minY, mapped.width, mapped.height],
    "integral_crop_rect_pixels": [mapped.integral.minX, mapped.integral.minY, mapped.integral.width, mapped.integral.height],
    "final_export_pixels": [width, height], "export_uniform_scale": scale,
    "intentional_padding_fraction": 1 - rect[2] * rect[3] / (canvas[0] * canvas[1]),
    "unintended_crop_fraction": combinedCorrection
]
try JSONSerialization.data(withJSONObject: transform, options: [.prettyPrinted, .sortedKeys])
    .write(to: URL(fileURLWithPath: args[4]), options: .atomic)
print(combinedCorrection)
