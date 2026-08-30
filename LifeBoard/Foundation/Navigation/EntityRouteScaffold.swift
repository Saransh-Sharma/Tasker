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
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        ScrollView {
            Group {
                switch state {
                case .loading:
                    ProgressView("Loading \(title.lowercased())…")
                case .loaded(let value):
                    content(value)
                        .frame(maxWidth: 720, alignment: .leading)
                case .missing:
                    StatusSurface(state: .unavailable, title: "\(title) not found", message: "It may have been deleted or changed on another device.")
                case .failed(let message):
                    StatusSurface(state: .recoverableError, title: "\(title) unavailable", message: message)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier("foundation.route.\(title.lowercased())")
    }
}
