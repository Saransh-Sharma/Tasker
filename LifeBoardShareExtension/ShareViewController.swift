import UIKit
import UniformTypeIdentifiers

@MainActor
final class ShareViewController: UIViewController {
    private var didBeginCapture = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard didBeginCapture == false else { return }
        didBeginCapture = true
        Task { await captureAndComplete() }
    }

    private func captureAndComplete() async {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let sourceTitle = items.compactMap { $0.attributedTitle?.string }.first
        let providers = items.flatMap { $0.attachments ?? [] }

        var sharedURL: URL?
        var text: String?
        for provider in providers {
            if sharedURL == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
               let url = Self.url(from: item) {
                sharedURL = url
            }
            if text == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) {
                text = Self.text(from: item)
            }
        }

        let rawText = [text, sharedURL?.absoluteString]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")

        if rawText.isEmpty == false {
            PendingCaptureInbox.append(PendingCapture(
                rawText: rawText,
                source: "share-extension",
                sharedURL: sharedURL,
                sourceTitle: sourceTitle
            ))
        }
        extensionContext?.completeRequest(returningItems: nil)
    }

    nonisolated private static func url(from item: NSSecureCoding?) -> URL? {
        item as? URL ?? (item as? NSURL).map { $0 as URL }
    }

    nonisolated private static func text(from item: NSSecureCoding?) -> String? {
        item as? String ?? (item as? NSAttributedString)?.string
    }
}
