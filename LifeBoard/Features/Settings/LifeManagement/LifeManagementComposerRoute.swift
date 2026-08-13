import SwiftUI
import UIKit

public enum SettingsRoute: Hashable, Sendable {
    case root
    case detail(SettingsDetailRoute)
}

public struct SettingsDependencies: @unchecked Sendable {
    public let destinationBuilder: @MainActor @Sendable (SettingsRoute) -> AnyView

    public init(
        destinationBuilder: @escaping @MainActor @Sendable (SettingsRoute) -> AnyView
    ) {
        self.destinationBuilder = destinationBuilder
    }
}

@MainActor
public enum SettingsRouteFactory {
    public static func destination(
        for route: SettingsRoute,
        dependencies: SettingsDependencies
    ) -> AnyView {
        dependencies.destinationBuilder(route)
    }
}

enum LifeManagementComposerRoute: Identifiable, Equatable {
    case area(LifeManagementLifeAreaDraft)
    case project(LifeManagementProjectDraft)

    var id: UUID {
        switch self {
        case .area(let draft):
            return draft.id
        case .project(let draft):
            return draft.id
        }
    }
}
