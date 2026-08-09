import SwiftUI
import SwiftData
import TranscriptionKit
import UIKit
import VisionKit

struct AtmosphereSnapshotReader<Content: View>: View {
    @Environment(\.lifeBoardAtmosphereSnapshot) private var snapshot
    private let content: (AtmosphereSnapshot) -> Content

    init(@ViewBuilder content: @escaping (AtmosphereSnapshot) -> Content) {
        self.content = content
    }

    var body: some View {
        content(snapshot)
    }
}

/// Keeps a type-erased destination value stable across shell-level updates.
///
/// `AnyView` caps generic metadata, but recreating the erased value on every
/// destination selection still copies the complete dashboard value graph. The
/// storage belongs to SwiftUI identity, so retained dashboards keep one root
/// value while an evicted Eva host releases its cached value with the host.
@MainActor
final class DestinationRootStorage: ObservableObject {
    private var root: AnyView?

    func resolve(_ makeRoot: () -> AnyView) -> AnyView {
        if let root {
            return root
        }
        let root = makeRoot()
        self.root = root
        return root
    }
}

struct StableDestinationRoot: View {
    @StateObject private var storage = DestinationRootStorage()
    let makeRoot: () -> AnyView

    var body: some View {
        storage.resolve(makeRoot)
    }
}
