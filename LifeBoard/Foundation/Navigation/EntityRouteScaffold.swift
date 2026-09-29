import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

enum RouteLoadState<Value> {
    case loading
    case loaded(Value)
    case missing
    case failed(String)
}

struct EntityRouteScaffold<Value, Content: View>: View {
    let title: String
    let systemImage: String
    let state: RouteLoadState<Value>
    /// Offered on a failed load. A recoverable error with no way to recover
    /// left the person on a dead end.
    var retry: (() -> Void)? = nil
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        ScrollView {
            Group {
                switch state {
                case .loading:
                    ProgressView("Loading…")
                case .loaded(let value):
                    content(value)
                        .frame(maxWidth: 720, alignment: .leading)
                case .missing:
                    StatusSurface(state: .unavailable, title: "\(title) not found", message: String(localized: "It may have been deleted."))
                case .failed(let message):
                    if let retry {
                        StatusSurface(state: .recoverableError, title: "\(title) unavailable", message: message, actionTitle: "Try again", action: retry)
                    } else {
                        StatusSurface(state: .recoverableError, title: "\(title) unavailable", message: message)
                    }
                }
            }
            .padding(24)
            // Centred: the 720-point column hugged the left edge of an iPad or
            // Mac window and left the right third empty.
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier("foundation.route.\(title.lowercased())")
    }
}
