import SwiftUI
@preconcurrency import UIKit
import Vision
@preconcurrency import VisionKit

public struct LifeBoardScannedDraft: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let pageCount: Int
    public var text: String

    public init(id: UUID = UUID(), pageCount: Int, text: String) {
        self.id = id
        self.pageCount = pageCount
        self.text = text
    }
}

public enum LifeBoardDocumentScanError: LocalizedError, Sendable {
    case unavailable
    case noReadableText
    case recognitionFailed

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            "Document scanning is unavailable on this device."
        case .noReadableText:
            "No readable text was found. You can retake the scan with steadier light."
        case .recognitionFailed:
            "LifeBoard couldn’t read that scan. Nothing was saved."
        }
    }
}

public struct LifeBoardDocumentScannerView: UIViewControllerRepresentable {
    public typealias UIViewControllerType = VNDocumentCameraViewController

    private let completion: @MainActor (Result<LifeBoardScannedDraft, Error>) -> Void
    private let cancellation: @MainActor () -> Void

    public init(
        completion: @escaping @MainActor (Result<LifeBoardScannedDraft, Error>) -> Void,
        cancellation: @escaping @MainActor () -> Void
    ) {
        self.completion = completion
        self.cancellation = cancellation
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion, cancellation: cancellation)
    }

    public func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    public func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    @MainActor
    public final class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        private let completion: @MainActor (Result<LifeBoardScannedDraft, Error>) -> Void
        private let cancellation: @MainActor () -> Void

        init(
            completion: @escaping @MainActor (Result<LifeBoardScannedDraft, Error>) -> Void,
            cancellation: @escaping @MainActor () -> Void
        ) {
            self.completion = completion
            self.cancellation = cancellation
        }

        public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            cancellation()
        }

        public func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            completion(.failure(error))
        }

        public func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let pages = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).jpegData(compressionQuality: 0.92) }
            let pageCount = scan.pageCount
            Task {
                do {
                    let text = try await Self.recognize(pages)
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.isEmpty == false else {
                        completion(.failure(LifeBoardDocumentScanError.noReadableText))
                        return
                    }
                    completion(.success(.init(pageCount: pageCount, text: trimmed)))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        private nonisolated static func recognize(_ pages: [Data]) async throws -> String {
            try await Task.detached(priority: .userInitiated) {
                var pageTexts: [String] = []
                for page in pages {
                    try Task.checkCancellation()
                    guard let image = UIImage(data: page)?.cgImage else { continue }
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    try VNImageRequestHandler(cgImage: image).perform([request])
                    let text = (request.results ?? [])
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                    if text.isEmpty == false { pageTexts.append(text) }
                }
                guard pageTexts.isEmpty == false else { throw LifeBoardDocumentScanError.noReadableText }
                return pageTexts.joined(separator: "\n\n")
            }.value
        }
    }
}

public struct LifeBoardScanReviewView: View {
    private let pageCount: Int
    private let onUse: (String) -> Void
    private let onCancel: () -> Void
    @State private var text: String

    public init(
        draft: LifeBoardScannedDraft,
        onUse: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        pageCount = draft.pageCount
        _text = State(initialValue: draft.text)
        self.onUse = onUse
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Review what LifeBoard read")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Nothing has been saved. Fix any words before placing this in your composer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
                    }
                    .accessibilityLabel("Scanned text")
                Text("\(pageCount) scanned page\(pageCount == 1 ? "" : "s") · processed locally")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use in composer") {
                        onUse(text.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

public enum LifeBoardBarcodeScanError: LocalizedError, Sendable {
    case unavailable
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .unavailable: "Barcode scanning is unavailable on this device. You can still enter a food manually."
        case .cancelled: "Scanning was cancelled."
        }
    }
}

#if targetEnvironment(macCatalyst)
/// Live barcode scanning is an iPhone/iPad camera feature; Catalyst callers
/// receive the same typed unavailability they already handle for devices
/// without DataScanner support.
public struct LifeBoardBarcodeScannerView: View {
    private let completion: @MainActor (Result<String, Error>) -> Void

    public init(completion: @escaping @MainActor (Result<String, Error>) -> Void) {
        self.completion = completion
    }

    public var body: some View {
        Color.clear.task { completion(.failure(LifeBoardBarcodeScanError.unavailable)) }
    }
}
#else
@available(iOS 16.0, *)
public struct LifeBoardBarcodeScannerView: UIViewControllerRepresentable {
    private let completion: @MainActor (Result<String, Error>) -> Void

    public init(completion: @escaping @MainActor (Result<String, Error>) -> Void) {
        self.completion = completion
    }

    public func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    public func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    public func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        guard !controller.isScanning else { return }
        do { try controller.startScanning() }
        catch { completion(.failure(LifeBoardBarcodeScanError.unavailable)) }
    }

    public static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    @MainActor
    public final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let completion: @MainActor (Result<String, Error>) -> Void
        private var didComplete = false

        init(completion: @escaping @MainActor (Result<String, Error>) -> Void) {
            self.completion = completion
        }

        public func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !didComplete else { return }
            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue?.filter(\.isNumber),
                      !payload.isEmpty else { continue }
                didComplete = true
                dataScanner.stopScanning()
                completion(.success(payload))
                return
            }
        }
    }
}
#endif

/// Availability check callers can use without touching DataScanner symbols,
/// which do not exist on Mac Catalyst.
public enum LifeBoardBarcodeScannerCapability {
    @MainActor
    public static var isAvailable: Bool {
        #if targetEnvironment(macCatalyst)
        false
        #else
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        #endif
    }
}
