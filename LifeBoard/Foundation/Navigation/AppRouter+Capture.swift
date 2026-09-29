import Foundation
import Observation

public struct CaptureRequest: Identifiable, Codable, Hashable, Sendable {
    public enum Source: String, Codable, Sendable {
        case shell
        case widget
        case appIntent
        case spotlight
        case shareExtension
        case deepLink
    }

    public let id: UUID
    public let kind: CaptureKind
    public let source: Source
    public let draftID: UUID?
    public let presentationContext: CapturePresentationContext?
    /// Seed text for the editor, used when reviewing an already-captured item.
    ///
    /// Carries the *raw* capture, not the parser's rewritten title: review means
    /// the user sees exactly what they said and decides what it becomes. Decoded
    /// with `decodeIfPresent` so previously persisted requests keep restoring.
    public let prefilledText: String?
    /// Structured capture metadata including proposals from universal input.
    public let captureSeed: CaptureSeed?

    public init(
        id: UUID = UUID(),
        kind: CaptureKind,
        source: Source,
        draftID: UUID? = nil,
        presentationContext: CapturePresentationContext? = nil,
        prefilledText: String? = nil,
        captureSeed: CaptureSeed? = nil
    ) {
        self.id = id
        self.kind = kind
        self.source = source
        self.draftID = draftID
        self.presentationContext = presentationContext
        self.prefilledText = prefilledText
        self.captureSeed = captureSeed
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(CaptureKind.self, forKey: .kind)
        source = try container.decode(Source.self, forKey: .source)
        draftID = try container.decodeIfPresent(UUID.self, forKey: .draftID)
        presentationContext = try container.decodeIfPresent(
            CapturePresentationContext.self,
            forKey: .presentationContext
        )
        prefilledText = try container.decodeIfPresent(String.self, forKey: .prefilledText)
        captureSeed = try container.decodeIfPresent(CaptureSeed.self, forKey: .captureSeed)
    }
}

@MainActor
@Observable
public final class CaptureRouter {
    public private(set) var activeRequest: CaptureRequest?
    public private(set) var pendingRequests: [CaptureRequest] = []
    public private(set) var recoverableDraftID: UUID?

    @ObservationIgnored var onStateChange: (@MainActor () -> Void)?

    public init() {}

    @discardableResult
    public func request(_ request: CaptureRequest) -> Bool {
        if activeRequest.map({ isSameLogicalRequest($0, request) }) == true
            || pendingRequests.contains(where: { isSameLogicalRequest($0, request) }) {
            return false
        }
        if activeRequest == nil {
            activeRequest = request
        } else {
            pendingRequests.append(request)
        }
        refreshRecoverableDraftID()
        onStateChange?()
        return true
    }

    public func request(
        kind: CaptureKind,
        source: CaptureRequest.Source,
        draftID: UUID? = nil,
        presentationContext: CapturePresentationContext? = nil
    ) {
        _ = request(CaptureRequest(
            kind: kind,
            source: source,
            draftID: draftID,
            presentationContext: presentationContext
        ))
    }

    /// Universal-input convenience: requests a capture while passing
    /// through the prefilled raw text and the structured `CaptureSeed`
    /// (parsed task proposals + input source) so editors can prefill
    /// and present correctable chips. The convenience keeps existing
    /// callers source-compatible.
    public func request(
        kind: CaptureKind,
        source: CaptureRequest.Source,
        prefilledText: String? = nil,
        captureSeed: CaptureSeed? = nil,
        draftID: UUID? = nil,
        presentationContext: CapturePresentationContext? = nil
    ) {
        _ = request(CaptureRequest(
            kind: kind,
            source: source,
            draftID: draftID,
            presentationContext: presentationContext,
            prefilledText: prefilledText,
            captureSeed: captureSeed
        ))
    }

    public func completeActiveRequest() {
        activeRequest = pendingRequests.isEmpty ? nil : pendingRequests.removeFirst()
        refreshRecoverableDraftID()
        onStateChange?()
    }

    public func cancelActiveRequest() {
        completeActiveRequest()
    }

    public func restoreRecoverableDraftID(_ draftID: UUID?) {
        recoverableDraftID = draftID
    }

    private func isSameLogicalRequest(_ lhs: CaptureRequest, _ rhs: CaptureRequest) -> Bool {
        lhs.kind == rhs.kind && lhs.draftID == rhs.draftID
    }

    private func refreshRecoverableDraftID() {
        recoverableDraftID = activeRequest?.draftID
            ?? pendingRequests.lazy.compactMap(\.draftID).first
    }
}
