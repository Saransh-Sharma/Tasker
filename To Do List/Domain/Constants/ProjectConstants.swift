//
//  ProjectConstants.swift
//  Tasker
//
//  Domain constants for Project management
//

import Foundation

/// Constants related to project management
public struct ProjectConstants {
    /// Fixed UUID for the Inbox project
    /// This UUID never changes and represents the default project for all tasks
    public static let inboxProjectID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// Name of the default Inbox project
    public static let inboxProjectName = "Inbox"

    /// Description of the Inbox project
    public static let inboxProjectDescription = "Default project for uncategorized tasks"

    private init() {
        // Prevent instantiation of constants struct
    }
}
