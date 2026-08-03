import AppKit
import AVFoundation
import CoreGraphics
import Foundation

private struct Sample: Sendable {
    let seconds: Double
    let image: CGImage
}

private enum ExtractionError: LocalizedError {
    case usage
    case invalidDuration
    case contactSheet

    var errorDescription: String? {
        switch self {
        case .usage: "Usage: extract_inspiration_frames.swift <video> <output-directory>"
        case .invalidDuration: "The inspiration video has no readable duration."
        case .contactSheet: "The contact sheet could not be rendered."
        }
    }
}

@main
private struct InspirationFrameExtractor {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else { throw ExtractionError.usage }

        let videoURL = URL(fileURLWithPath: arguments[1])
        let outputURL = URL(fileURLWithPath: arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = duration.seconds
        guard durationSeconds.isFinite, durationSeconds > 0 else { throw ExtractionError.invalidDuration }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 960, height: 960)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let evenTimes = (0..<12).map { index in
            durationSeconds * (0.04 + (0.92 * Double(index) / 11.0))
        }
        let probeTimes = (0..<48).map { index in
            durationSeconds * Double(index) / 47.0
        }

        var sceneTimes: [Double] = []
        var previousSignature: [Double]?
        for seconds in probeTimes {
            let image = try await frame(generator: generator, seconds: seconds)
            let signature = luminanceSignature(image)
            if let previousSignature, signatureDistance(previousSignature, signature) >= 0.115 {
                if sceneTimes.last.map({ seconds - $0 >= 0.45 }) ?? true {
                    sceneTimes.append(seconds)
                }
            }
            previousSignature = signature
            if sceneTimes.count == 8 { break }
        }

        let selectedTimes = deduplicatedTimes(evenTimes + sceneTimes, minimumSpacing: 0.22)
        var samples: [Sample] = []
        for (index, seconds) in selectedTimes.enumerated() {
            let image = try await frame(generator: generator, seconds: seconds)
            let name = String(format: "frame-%02d-%06.2fs.png", index + 1, seconds)
            try pngData(for: image).write(to: outputURL.appendingPathComponent(name), options: .atomic)
            samples.append(Sample(seconds: seconds, image: image))
        }

        let sheet = try contactSheet(samples)
        try pngData(for: sheet).write(
            to: outputURL.appendingPathComponent("inspiration-contact-sheet.png"),
            options: .atomic
        )

        let manifest = manifestText(
            videoURL: videoURL,
            durationSeconds: durationSeconds,
            evenCount: evenTimes.count,
            sceneCount: sceneTimes.count,
            samples: samples
        )
        try manifest.write(
            to: outputURL.appendingPathComponent("FRAME_MANIFEST.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func frame(generator: AVAssetImageGenerator, seconds: Double) async throws -> CGImage {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        return try await generator.image(at: time).image
    }

    private static func pngData(for image: CGImage) throws -> Data {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw ExtractionError.contactSheet
        }
        return data
    }

    private static func luminanceSignature(_ image: CGImage) -> [Double] {
        let width = 12
        let height = 12
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 0, to: bytes.count, by: 4).map { index in
            let red = Double(bytes[index]) / 255
            let green = Double(bytes[index + 1]) / 255
            let blue = Double(bytes[index + 2]) / 255
            return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        }
    }

    private static func signatureDistance(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, lhs.isEmpty == false else { return 0 }
        return zip(lhs, rhs).reduce(0) { result, pair in
            result + abs(pair.0 - pair.1)
        } / Double(lhs.count)
    }

    private static func deduplicatedTimes(_ times: [Double], minimumSpacing: Double) -> [Double] {
        var result: [Double] = []
        for value in times.sorted() where result.last.map({ value - $0 >= minimumSpacing }) ?? true {
            result.append(value)
        }
        return result
    }

    private static func contactSheet(_ samples: [Sample]) throws -> CGImage {
        let columns = 4
        let cellWidth = 280
        let imageHeight = 190
        let labelHeight = 30
        let cellHeight = imageHeight + labelHeight
        let rows = Int(ceil(Double(samples.count) / Double(columns)))
        let width = columns * cellWidth
        let height = max(1, rows) * cellHeight

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ExtractionError.contactSheet }

        context.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        for (index, sample) in samples.enumerated() {
            let column = index % columns
            let row = index / columns
            let originX = column * cellWidth
            let originY = height - ((row + 1) * cellHeight)
            let imageRect = aspectFillRect(
                imageSize: CGSize(width: sample.image.width, height: sample.image.height),
                destination: CGRect(x: originX + 4, y: originY + labelHeight, width: cellWidth - 8, height: imageHeight - 4)
            )
            context.saveGState()
            context.clip(to: CGRect(x: originX + 4, y: originY + labelHeight, width: cellWidth - 8, height: imageHeight - 4))
            context.draw(sample.image, in: imageRect)
            context.restoreGState()

            let label = String(format: "%02d  ·  %.2fs", index + 1, sample.seconds)
            let attributed = NSAttributedString(
                string: label,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: NSColor.white
                ]
            )
            let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphicsContext
            attributed.draw(at: CGPoint(x: originX + 10, y: originY + 7))
            NSGraphicsContext.restoreGraphicsState()
        }

        guard let image = context.makeImage() else { throw ExtractionError.contactSheet }
        return image
    }

    private static func aspectFillRect(imageSize: CGSize, destination: CGRect) -> CGRect {
        let scale = max(destination.width / imageSize.width, destination.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(
            x: destination.midX - width / 2,
            y: destination.midY - height / 2,
            width: width,
            height: height
        )
    }

    private static func manifestText(
        videoURL: URL,
        durationSeconds: Double,
        evenCount: Int,
        sceneCount: Int,
        samples: [Sample]
    ) -> String {
        let rows = samples.enumerated().map { index, sample in
            String(format: "| %02d | %.2f s | `frame-%02d-%06.2fs.png` |", index + 1, sample.seconds, index + 1, sample.seconds)
        }.joined(separator: "\n")
        return """
        # Inspiration video frame manifest

        Source: `\(videoURL.lastPathComponent)`  
        Duration: \(String(format: "%.2f", durationSeconds)) seconds  
        Selection: \(evenCount) evenly spaced anchors plus \(sceneCount) visual-change candidates, deduplicated to \(samples.count) frames.

        These frames are private design evidence only. They are not application assets and must not be added to an app target.

        | Frame | Time | File |
        |---:|---:|---|
        \(rows)
        """
    }
}
