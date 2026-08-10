import Foundation

public struct KnowledgeSearchDocument: Hashable, Sendable {
    public var noteID: UUID
    public var title: String
    public var body: String
    public var tags: String
    public var attachments: String
    public var updatedAt: Date
    public var isLocked: Bool

    public init(
        noteID: UUID,
        title: String,
        body: String,
        tags: String,
        attachments: String,
        updatedAt: Date,
        isLocked: Bool
    ) {
        self.noteID = noteID
        self.title = title
        self.body = body
        self.tags = tags
        self.attachments = attachments
        self.updatedAt = updatedAt
        self.isLocked = isLocked
    }
}
