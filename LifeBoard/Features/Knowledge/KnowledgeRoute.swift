import LifeBoardDomain
import SwiftUI

public enum KnowledgeRoute: Hashable, Sendable {
    case library
    case note(UUID)
    case folder(UUID)
}

public struct KnowledgeDependencies: Sendable {
    public let repository: any KnowledgeRepository

    public init(repository: any KnowledgeRepository) {
        self.repository = repository
    }
}

@MainActor
public enum KnowledgeRouteFactory {
    public static func destination(
        for route: KnowledgeRoute,
        dependencies: KnowledgeDependencies
    ) -> AnyView {
        switch route {
        case .library:
            AnyView(KnowledgeModuleView(repository: dependencies.repository))
        case .note(let id):
            AnyView(KnowledgeModuleView(repository: dependencies.repository, initialNoteID: id))
        case .folder(let id):
            AnyView(KnowledgeModuleView(repository: dependencies.repository, initialFolderID: id))
        }
    }

    public static func captureDestination(
        repository: any KnowledgeRepository,
        captureDraftID: UUID?,
        initialText: String?
    ) -> AnyView {
        AnyView(
            KnowledgeModuleView(
                repository: repository,
                startsWithNewNote: true,
                captureDraftID: captureDraftID,
                initialText: initialText
            )
        )
    }
}
