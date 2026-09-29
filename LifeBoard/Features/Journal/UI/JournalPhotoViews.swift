import AVFAudio
import CoreSpotlight
import Foundation
import LifeBoardDomain
import LocalAuthentication
import LifeBoardPersistence
import Observation
import PhotosUI
import LifeBoardDomain
import Speech
import SwiftUI
import LifeBoardTranscription
import UIKit
import UniformTypeIdentifiers
import LifeBoardContracts

public enum JournalPhotoCropMode: String, CaseIterable, Sendable {
    case original
    case square
    case portrait
}

@MainActor
public enum JournalPhotoProcessor {
    public static func edit(
        payload: Data,
        clockwiseQuarterTurns: Int,
        cropMode: JournalPhotoCropMode
    ) -> Data? {
        guard let source = UIImage(data: payload), let normalized = normalized(source) else { return nil }
        let turns = ((clockwiseQuarterTurns % 4) + 4) % 4
        let rotated = (0..<turns).reduce(normalized) { image, _ in rotateClockwise(image) }
        let cropped = crop(rotated, mode: cropMode)
        return cropped.jpegData(compressionQuality: 0.92) ?? cropped.pngData()
    }

    private static func normalized(_ image: UIImage) -> UIImage? {
        let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func rotateClockwise(_ image: UIImage) -> UIImage {
        let outputSize = CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            context.cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            context.cgContext.rotate(by: .pi / 2)
            image.draw(in: CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ))
        }
    }

    private static func crop(_ image: UIImage, mode: JournalPhotoCropMode) -> UIImage {
        let targetAspect: CGFloat?
        switch mode {
        case .original: targetAspect = nil
        case .square: targetAspect = 1
        case .portrait: targetAspect = 4 / 5
        }
        guard let targetAspect else { return image }
        let imageAspect = image.size.width / image.size.height
        let cropSize: CGSize
        if imageAspect > targetAspect {
            cropSize = CGSize(width: image.size.height * targetAspect, height: image.size.height)
        } else {
            cropSize = CGSize(width: image.size.width, height: image.size.width / targetAspect)
        }
        let origin = CGPoint(
            x: (image.size.width - cropSize.width) / 2,
            y: (image.size.height - cropSize.height) / 2
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: cropSize, format: format).image { _ in
            image.draw(at: CGPoint(x: -origin.x, y: -origin.y))
        }
    }
}

struct JournalPhotoEditor: View {
    let payload: Data
    let onSave: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var quarterTurns = 0
    @State private var cropMode: JournalPhotoCropMode = .original
    @State private var editedPayload: Data

    init(payload: Data, onSave: @escaping (Data) -> Void) {
        self.payload = payload
        self.onSave = onSave
        _editedPayload = State(initialValue: payload)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let image = UIImage(data: editedPayload) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityLabel("Photo preview")
                } else {
                    StatusSurface(state: .unavailable, title: String(localized: "Photo unavailable"), message: String(localized: "This photo isn’t on this device."))
                }
                // Was `.pickerStyle(.segmented)`, the stock grey segmented control.
                // `OptionRail` is the design system's equivalent and keeps the
                // semantics: one selection, per-value accessibility identifiers,
                // and reflow at accessibility text sizes.
                OptionRail(
                    "Crop",
                    selection: $cropMode,
                    values: [.original, .square, .portrait],
                    identifierPrefix: "journal.photo.crop",
                    title: { crop in
                        switch crop {
                        case .original: "Original"
                        case .square: "Square"
                        case .portrait: "4:5"
                        }
                    }
                )
                HStack {
                    Button("Rotate", systemImage: "rotate.right") {
                        quarterTurns = (quarterTurns + 1) % 4
                        updatePreview()
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        quarterTurns = 0
                        cropMode = .original
                        editedPayload = payload
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.lifeBoardChip)
            }
            .padding(20)
            .background(Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea())
            .navigationTitle("Edit photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(editedPayload) }
                        .disabled(UIImage(data: editedPayload) == nil)
                }
            }
            .onChange(of: cropMode) { _, _ in updatePreview() }
        }
    }

    private func updatePreview() {
        editedPayload = JournalPhotoProcessor.edit(
            payload: payload,
            clockwiseQuarterTurns: quarterTurns,
            cropMode: cropMode
        ) ?? payload
    }
}

struct JournalExportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct JournalPhotoActivitySheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct JournalPhotoInspector: View {
    let media: JournalMediaValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var zoom: CGFloat = 1
    @State private var startingZoom: CGFloat = 1
    @State private var showsShare = false

    private var image: UIImage? {
        media.payload.flatMap(UIImage.init(data:))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(zoom)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(24)
                            .accessibilityLabel("Photo")
                            .onTapGesture(count: 2) {
                                withAnimation(MotionProfile.controlMorph.animation(reduceMotion: reduceMotion)) {
                                    zoom = 1
                                    startingZoom = 1
                                }
                            }
                            .gesture(
                                MagnifyGesture()
                                    .onChanged { value in
                                        zoom = min(max(startingZoom * value.magnification, 1), 5)
                                    }
                                    .onEnded { _ in
                                        startingZoom = zoom
                                    }
                            )
                    }
                    .scrollIndicators(.hidden)
                    .background(Color.lifeboard(.overlayScrim).ignoresSafeArea())
                } else {
                    StatusSurface(
                        state: .unavailable,
                        title: String(localized: "Photo unavailable"),
                        message: String(localized: "This photo isn’t on this device.")
                    )
                }
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.lifeboard(.overlayScrim), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                if image != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Share", systemImage: "square.and.arrow.up") {
                            showsShare = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showsShare) {
                if let image { JournalPhotoActivitySheet(image: image) }
            }
        }
    }
}
