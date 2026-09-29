import LifeBoardContracts
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// "Save to LifeBoard" from the share sheet.
///
/// It used to save silently and dismiss the moment it appeared: the sheet just
/// vanished, nobody knew whether anything was kept, and an image or file shared
/// alongside text was dropped without a word. Now it shows what will be saved,
/// lets the person fix the title, and says plainly what it can't keep yet.
/// The save path is unchanged: raw text into the App Group `PendingCapture`
/// queue, which the app drains into the Inbox.
@MainActor
final class ShareViewController: UIViewController {
    private let model = ShareCaptureModel()
    private var didBeginLoading = false

    override func viewDidLoad() {
        super.viewDidLoad()
        model.onFinish = { [weak self] saved in
            guard let self else { return }
            if saved {
                self.extensionContext?.completeRequest(returningItems: nil)
            } else {
                self.extensionContext?.cancelRequest(
                    withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
                )
            }
        }
        let host = UIHostingController(rootView: ShareCaptureView(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard didBeginLoading == false else { return }
        didBeginLoading = true
        Task { await loadSharedItems() }
    }

    private func loadSharedItems() async {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let sourceTitle = items.compactMap { $0.attributedTitle?.string }.first
        let providers = items.flatMap { $0.attachments ?? [] }

        var sharedURL: URL?
        var text: String?
        var unsupported: Set<ShareUnsupportedKind> = []
        for provider in providers {
            if sharedURL == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
               let url = Self.url(from: item) {
                // A file shared from Files arrives as a file URL. Its path means
                // nothing once the share sheet closes, so it isn't saved.
                if url.isFileURL {
                    unsupported.insert(.file)
                } else {
                    sharedURL = url
                }
            }
            if text == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) {
                text = Self.text(from: item)
            }
            if let kind = ShareUnsupportedKind(provider: provider) {
                unsupported.insert(kind)
            }
        }

        model.prepare(text: text, sharedURL: sharedURL, sourceTitle: sourceTitle, unsupported: unsupported)
    }

    nonisolated private static func url(from item: NSSecureCoding?) -> URL? {
        item as? URL ?? (item as? NSURL).map { $0 as URL }
    }

    nonisolated private static func text(from item: NSSecureCoding?) -> String? {
        item as? String ?? (item as? NSAttributedString)?.string
    }
}

/// Attachments the Inbox can't keep yet. Named so the sheet can say which.
enum ShareUnsupportedKind: Hashable {
    case image, video, audio, file

    init?(provider: NSItemProvider) {
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            self = .image
        } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            self = .video
        } else if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
            self = .audio
        } else if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier)
                    || provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            self = .file
        } else {
            return nil
        }
    }

    var pluralNoun: String {
        switch self {
        case .image: "Images"
        case .video: "Videos"
        case .audio: "Audio"
        case .file: "Files"
        }
    }
}

@MainActor
final class ShareCaptureModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case nothingToSave
        case saving
        case saved
        case failed
    }

    @Published var phase: Phase = .loading
    @Published var title = ""
    @Published private(set) var bodyText: String?
    @Published private(set) var sharedURL: URL?
    @Published private(set) var unsupported: Set<ShareUnsupportedKind> = []

    var onFinish: ((Bool) -> Void)?
    private var sourceTitle: String?

    /// What the Inbox receives: the title the person settled on, then the
    /// shared text (unless it is just the title again), then the link.
    var rawText: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines: [String] = []
        if trimmedTitle.isEmpty == false { lines.append(trimmedTitle) }
        if let bodyText, bodyText != trimmedTitle { lines.append(bodyText) }
        if let sharedURL, lines.contains(sharedURL.absoluteString) == false {
            lines.append(sharedURL.absoluteString)
        }
        return lines.joined(separator: "\n")
    }

    /// One line about attachments that won't come along, or nil.
    var unsupportedNote: String? {
        guard unsupported.isEmpty == false else { return nil }
        let nouns = [ShareUnsupportedKind.image, .video, .audio, .file]
            .filter(unsupported.contains)
            .map(\.pluralNoun)
        let subject = ListFormatter.localizedString(byJoining: nouns)
        if phase == .nothingToSave {
            return "\(subject) can’t be saved to LifeBoard yet."
        }
        let kept = switch (bodyText != nil, sharedURL != nil) {
        case (true, true): "the text and link"
        case (false, true): "the link"
        default: "the text"
        }
        return "\(subject) can’t be saved yet. Only \(kept) will be saved."
    }

    func prepare(text: String?, sharedURL: URL?, sourceTitle: String?, unsupported: Set<ShareUnsupportedKind>) {
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bodyText = trimmedText?.isEmpty == false ? trimmedText : nil
        self.sharedURL = sharedURL
        self.sourceTitle = sourceTitle
        self.unsupported = unsupported

        let firstLine = bodyText?
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)
        let proposedTitle = sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let proposedTitle, proposedTitle.isEmpty == false {
            title = proposedTitle
        } else if let firstLine, firstLine.count <= 120 {
            title = firstLine
        } else {
            title = sharedURL?.host() ?? ""
        }
        phase = (bodyText == nil && sharedURL == nil) ? .nothingToSave : .ready
    }

    func save() {
        guard phase == .ready || phase == .failed else { return }
        let text = rawText
        guard text.isEmpty == false else { return }
        phase = .saving
        let saved = PendingCaptureInbox.append(PendingCapture(
            rawText: text,
            source: "share-extension",
            sharedURL: sharedURL,
            sourceTitle: sourceTitle
        ))
        guard saved else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            phase = .failed
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        phase = .saved
        Task { @MainActor [weak self] in
            // Long enough to read "Saved to Inbox", short enough not to wait on.
            try? await Task.sleep(for: .milliseconds(900))
            self?.onFinish?(true)
        }
    }

    func cancel() {
        onFinish?(false)
    }
}

struct ShareCaptureView: View {
    @ObservedObject var model: ShareCaptureModel
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Save to LifeBoard")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if model.phase != .saved {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(model.phase == .nothingToSave ? "Close" : "Cancel") { model.cancel() }
                        }
                    }
                    if model.phase == .ready || model.phase == .failed || model.phase == .saving {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save to Inbox") { model.save() }
                                .disabled(model.rawText.isEmpty || model.phase == .saving)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .saved:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Saved to Inbox")
                    .font(.headline)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        case .nothingToSave:
            ContentUnavailableView {
                Label("Nothing to save", systemImage: "tray")
            } description: {
                Text(model.unsupportedNote ?? "Only text and links can be saved.")
            }
        case .ready, .saving, .failed:
            Form {
                Section("Title") {
                    TextField("Title", text: $model.title, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($titleFocused)
                        .submitLabel(.done)
                }
                if model.bodyText != nil || model.sharedURL != nil {
                    Section("Saving") {
                        if let bodyText = model.bodyText, bodyText != model.title.trimmingCharacters(in: .whitespacesAndNewlines) {
                            Text(bodyText)
                                .font(.subheadline)
                                .lineLimit(6)
                        }
                        if let url = model.sharedURL {
                            Label {
                                Text(url.absoluteString)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            } icon: {
                                Image(systemName: "link")
                            }
                        }
                    }
                }
                if let note = model.unsupportedNote {
                    Section {
                        Label(note, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if model.phase == .failed {
                    Section {
                        Label("Couldn’t save to your Inbox. Try again.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}
