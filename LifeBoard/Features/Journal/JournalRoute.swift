import SwiftUI
import LifeBoardDomain

public enum JournalRoute: Hashable, Sendable {
    case day(UUID)
    case search
    case weeklyReflection(Date)
    case capture
}

public struct JournalDependencies: Sendable {
    public let derivedIndex: (any JournalDerivedIndexRepository)?
    public let destinationBuilder: @MainActor @Sendable (JournalRoute) -> AnyView

    public init(
        derivedIndex: (any JournalDerivedIndexRepository)? = nil,
        destinationBuilder: @escaping @MainActor @Sendable (JournalRoute) -> AnyView
    ) {
        self.derivedIndex = derivedIndex
        self.destinationBuilder = destinationBuilder
    }
}

@MainActor
public enum JournalRouteFactory {
    public static func destination(
        for route: JournalRoute,
        dependencies: JournalDependencies
    ) -> AnyView {
        dependencies.destinationBuilder(route)
    }
}
