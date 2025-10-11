//
//  TaskCollaborationUseCase.swift
//  Tasker
//
//  Use case for team task sharing and collaboration features
//

import Foundation

/// Use case for managing task collaboration and team sharing
public final class TaskCollaborationUseCase {
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let collaborationRepository: CollaborationRepositoryProtocol
    private let notificationService: NotificationServiceProtocol?
    private let syncService: TaskCollaborationSyncService?
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        collaborationRepository: CollaborationRepositoryProtocol,
        notificationService: NotificationServiceProtocol? = nil,
        syncService: TaskCollaborationSyncService? = nil
    ) {
        self.taskRepository = taskRepository
        self.userRepository = userRepository
        self.collaborationRepository = collaborationRepository
        self.notificationService = notificationService
        self.syncService = syncService
    }
    
    // MARK: - Task Sharing
    
    /// Share a task with team members
    public func shareTask(
        taskId: UUID,
        with users: [UUID],
        permissions: CollaborationPermissions = .view,
        message: String? = nil,
        completion: @escaping (Result<TaskSharingResult, CollaborationError>) -> Void
    ) {
        // Validate task exists
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let task):
                guard let task = task else {
                    completion(.failure(.taskNotFound))
                    return
                }
                self?.processTaskSharing(
                    task: task,
                    userIds: users,
                    permissions: permissions,
                    message: message,
                    completion: completion
                )
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Share multiple tasks as a collection
    public func shareTaskCollection(
        taskIds: [UUID],
        with users: [UUID],
        collectionName: String,
        permissions: CollaborationPermissions = .view,
        completion: @escaping (Result<CollectionSharingResult, CollaborationError>) -> Void
    ) {
        // Fetch all tasks
        let group = DispatchGroup()
        var tasks: [Task] = []
        var fetchErrors: [Error] = []
        
        for taskId in taskIds {
            group.enter()
            taskRepository.fetchTask(withId: taskId) { result in
                switch result {
                case .success(let task):
                    if let task = task {
                        tasks.append(task)
                    } else {
                        fetchErrors.append(CollaborationError.taskNotFound)
                    }
                case .failure(let error):
                    fetchErrors.append(error)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard fetchErrors.isEmpty else {
                completion(.failure(.multipleTasksNotFound))
                return
            }
            
            self?.processCollectionSharing(
                tasks: tasks,
                userIds: users,
                collectionName: collectionName,
                permissions: permissions,
                completion: completion
            )
        }
    }
    
    /// Get shared tasks for current user
    public func getSharedTasks(completion: @escaping (Result<[SharedTask], CollaborationError>) -> Void) {
        collaborationRepository.fetchSharedTasks { result in
            switch result {
            case .success(let sharedTasks):
                completion(.success(sharedTasks))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Get tasks shared by current user
    public func getTasksSharedByMe(completion: @escaping (Result<[SharedTask], CollaborationError>) -> Void) {
        collaborationRepository.fetchTasksSharedByUser { result in
            switch result {
            case .success(let sharedTasks):
                completion(.success(sharedTasks))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Collaboration Management
    
    /// Update collaboration permissions
    public func updateCollaborationPermissions(
        taskId: UUID,
        userId: UUID,
        newPermissions: CollaborationPermissions,
        completion: @escaping (Result<Void, CollaborationError>) -> Void
    ) {
        collaborationRepository.updatePermissions(
            taskId: taskId,
            userId: userId,
            permissions: newPermissions
        ) { [weak self] result in
            switch result {
            case .success:
                // Notify affected user
                self?.notifyPermissionChange(taskId: taskId, userId: userId, permissions: newPermissions)
                completion(.success(()))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Revoke task sharing
    public func revokeTaskSharing(
        taskId: UUID,
        fromUserId: UUID,
        completion: @escaping (Result<Void, CollaborationError>) -> Void
    ) {
        collaborationRepository.revokeAccess(taskId: taskId, userId: fromUserId) { [weak self] result in
            switch result {
            case .success:
                // Notify user about revoked access
                self?.notifyAccessRevoked(taskId: taskId, userId: fromUserId)
                completion(.success(()))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Get collaboration details for a task
    public func getCollaborationDetails(
        for taskId: UUID,
        completion: @escaping (Result<TaskCollaborationInfo, CollaborationError>) -> Void
    ) {
        collaborationRepository.fetchCollaborationInfo(taskId: taskId) { result in
            switch result {
            case .success(let info):
                completion(.success(info))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Team Task Management
    
    /// Assign task to team member
    public func assignTask(
        taskId: UUID,
        to userId: UUID,
        withDeadline deadline: Date? = nil,
        completion: @escaping (Result<TaskAssignmentResult, CollaborationError>) -> Void
    ) {
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let taskOptional):
                guard var task = taskOptional else {
                    completion(.failure(.taskNotFound))
                    return
                }
                // Note: assignedUserId property doesn't exist on Task model
                // This would require extending the Task model or using a different approach
                // For now, we'll skip this assignment and focus on the collaboration record
                // task.assignedUserId = userId
                if let deadline = deadline {
                    task.dueDate = deadline
                }
                
                self?.taskRepository.updateTask(task) { updateResult in
                    switch updateResult {
                    case .success(let updatedTask):
                        // Create assignment record
                        let assignment = TaskAssignment(
                            taskId: taskId,
                            assignedUserId: userId,
                            assignedDate: Date(),
                            deadline: deadline
                        )
                        
                        self?.collaborationRepository.saveTaskAssignment(assignment) { saveResult in
                            switch saveResult {
                            case .success:
                                // Notify assigned user
                                self?.notifyTaskAssignment(task: updatedTask, assignedUserId: userId)
                                
                                let result = TaskAssignmentResult(
                                    task: updatedTask,
                                    assignedUser: userId,
                                    assignmentDate: Date()
                                )
                                completion(.success(result))
                            case .failure(let error):
                                completion(.failure(.repositoryError(error)))
                            }
                        }
                    case .failure(let error):
                        completion(.failure(.repositoryError(error)))
                    }
                }
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Get team task assignments
    public func getTeamAssignments(completion: @escaping (Result<[TaskAssignment], CollaborationError>) -> Void) {
        collaborationRepository.fetchTeamAssignments { result in
            switch result {
            case .success(let assignments):
                completion(.success(assignments))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Create team task template
    public func createTeamTaskTemplate(
        name: String,
        tasks: [CreateTaskRequest],
        assignmentRules: [AssignmentRule],
        completion: @escaping (Result<TeamTaskTemplate, CollaborationError>) -> Void
    ) {
        let template = TeamTaskTemplate(
            id: UUID(),
            name: name,
            tasks: tasks,
            assignmentRules: assignmentRules,
            createdDate: Date()
        )
        
        collaborationRepository.saveTeamTemplate(template) { result in
            switch result {
            case .success:
                completion(.success(template))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Real-time Collaboration
    
    /// Start collaborative session for a task
    public func startCollaborativeSession(
        taskId: UUID,
        completion: @escaping (Result<CollaborativeSession, CollaborationError>) -> Void
    ) {
        let session = CollaborativeSession(
            id: UUID(),
            taskId: taskId,
            startTime: Date(),
            participants: [],
            isActive: true
        )
        
        collaborationRepository.saveCollaborativeSession(session) { [weak self] result in
            switch result {
            case .success:
                // Start real-time sync for this session
                self?.syncService?.startRealtimeSync(for: taskId)
                completion(.success(session))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Join collaborative session
    public func joinCollaborativeSession(
        sessionId: UUID,
        completion: @escaping (Result<CollaborativeSession, CollaborationError>) -> Void
    ) {
        collaborationRepository.joinSession(sessionId: sessionId) { result in
            switch result {
            case .success(let session):
                completion(.success(session))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// End collaborative session
    public func endCollaborativeSession(
        sessionId: UUID,
        completion: @escaping (Result<CollaborativeSessionSummary, CollaborationError>) -> Void
    ) {
        collaborationRepository.endSession(sessionId: sessionId) { [weak self] result in
            switch result {
            case .success(let summary):
                // Stop real-time sync
                if let taskId = summary.taskId {
                    self?.syncService?.stopRealtimeSync(for: taskId)
                }
                completion(.success(summary))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Comments and Communication
    
    /// Add comment to shared task
    public func addComment(
        to taskId: UUID,
        content: String,
        mentionedUsers: [UUID] = [],
        completion: @escaping (Result<TaskComment, CollaborationError>) -> Void
    ) {
        let comment = TaskComment(
            id: UUID(),
            taskId: taskId,
            content: content,
            authorId: getCurrentUserId(),
            createdDate: Date(),
            mentionedUsers: mentionedUsers
        )
        
        collaborationRepository.saveComment(comment) { [weak self] result in
            switch result {
            case .success:
                // Notify mentioned users and task collaborators
                self?.notifyNewComment(comment: comment)
                completion(.success(comment))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Get comments for a task
    public func getComments(
        for taskId: UUID,
        completion: @escaping (Result<[TaskComment], CollaborationError>) -> Void
    ) {
        collaborationRepository.fetchComments(taskId: taskId) { result in
            switch result {
            case .success(let comments):
                completion(.success(comments))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Update comment
    public func updateComment(
        commentId: UUID,
        newContent: String,
        completion: @escaping (Result<TaskComment, CollaborationError>) -> Void
    ) {
        collaborationRepository.updateComment(
            commentId: commentId,
            content: newContent
        ) { result in
            switch result {
            case .success(let comment):
                completion(.success(comment))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Activity Tracking
    
    /// Get collaboration activity for a task
    public func getCollaborationActivity(
        for taskId: UUID,
        completion: @escaping (Result<[CollaborationActivity], CollaborationError>) -> Void
    ) {
        collaborationRepository.fetchActivity(taskId: taskId) { result in
            switch result {
            case .success(let activities):
                completion(.success(activities))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Track user activity on shared task
    public func trackActivity(
        taskId: UUID,
        activityType: ActivityType,
        details: String? = nil
    ) {
        let activity = CollaborationActivity(
            id: UUID(),
            taskId: taskId,
            userId: getCurrentUserId(),
            activityType: activityType,
            details: details,
            timestamp: Date()
        )
        
        collaborationRepository.saveActivity(activity) { _ in
            // Activity saved in background
        }
    }
    
    // MARK: - Private Methods
    
    private func processTaskSharing(
        task: Task,
        userIds: [UUID],
        permissions: CollaborationPermissions,
        message: String?,
        completion: @escaping (Result<TaskSharingResult, CollaborationError>) -> Void
    ) {
        let sharingRecord = TaskSharingRecord(
            taskId: task.id,
            sharedWithUsers: userIds,
            permissions: permissions,
            shareDate: Date(),
            message: message
        )
        
        collaborationRepository.saveTaskSharing(sharingRecord) { [weak self] result in
            switch result {
            case .success:
                // Notify users about shared task
                for userId in userIds {
                    self?.notifyTaskShared(task: task, userId: userId, message: message)
                }
                
                let result = TaskSharingResult(
                    task: task,
                    sharedWith: userIds,
                    permissions: permissions,
                    shareDate: Date()
                )
                completion(.success(result))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    private func processCollectionSharing(
        tasks: [Task],
        userIds: [UUID],
        collectionName: String,
        permissions: CollaborationPermissions,
        completion: @escaping (Result<CollectionSharingResult, CollaborationError>) -> Void
    ) {
        let collection = TaskCollection(
            id: UUID(),
            name: collectionName,
            taskIds: tasks.map { $0.id },
            createdDate: Date()
        )
        
        collaborationRepository.saveTaskCollection(collection) { [weak self] result in
            switch result {
            case .success:
                // Share collection with users
                let sharingRecord = CollectionSharingRecord(
                    collectionId: collection.id,
                    sharedWithUsers: userIds,
                    permissions: permissions,
                    shareDate: Date()
                )
                
                self?.collaborationRepository.saveCollectionSharing(sharingRecord) { shareResult in
                    switch shareResult {
                    case .success:
                        // Notify users about shared collection
                        for userId in userIds {
                            self?.notifyCollectionShared(collection: collection, userId: userId)
                        }
                        
                        let result = CollectionSharingResult(
                            collection: collection,
                            tasks: tasks,
                            sharedWith: userIds,
                            permissions: permissions
                        )
                        completion(.success(result))
                        
                    case .failure(let error):
                        completion(.failure(.repositoryError(error)))
                    }
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Notification Helpers
    
    private func notifyTaskShared(task: Task, userId: UUID, message: String?) {
        let notification = CollaborationNotification(
            type: .taskShared,
            taskId: task.id,
            message: message ?? "A task has been shared with you",
            recipientId: userId
        )
        notificationService?.send(notification)
    }
    
    private func notifyCollectionShared(collection: TaskCollection, userId: UUID) {
        let notification = CollaborationNotification(
            type: .collectionShared,
            taskId: nil,
            message: "Task collection '\(collection.name)' has been shared with you",
            recipientId: userId
        )
        notificationService?.send(notification)
    }
    
    private func notifyTaskAssignment(task: Task, assignedUserId: UUID) {
        let notification = CollaborationNotification(
            type: .taskAssigned,
            taskId: task.id,
            message: "You have been assigned task: \(task.name)",
            recipientId: assignedUserId
        )
        notificationService?.send(notification)
    }
    
    private func notifyPermissionChange(taskId: UUID, userId: UUID, permissions: CollaborationPermissions) {
        let notification = CollaborationNotification(
            type: .permissionChanged,
            taskId: taskId,
            message: "Your permissions have been updated to: \(permissions.description)",
            recipientId: userId
        )
        notificationService?.send(notification)
    }
    
    private func notifyAccessRevoked(taskId: UUID, userId: UUID) {
        let notification = CollaborationNotification(
            type: .accessRevoked,
            taskId: taskId,
            message: "Your access to a shared task has been revoked",
            recipientId: userId
        )
        notificationService?.send(notification)
    }
    
    private func notifyNewComment(comment: TaskComment) {
        // Notify mentioned users
        for userId in comment.mentionedUsers {
            let notification = CollaborationNotification(
                type: .commentMention,
                taskId: comment.taskId,
                message: "You were mentioned in a comment",
                recipientId: userId
            )
            notificationService?.send(notification)
        }
    }
    
    private func getCurrentUserId() -> UUID {
        // This would typically come from a user session service
        return UUID()
    }
}

// MARK: - Models and Types

public struct SharedTask {
    public let task: Task
    public let sharedBy: UUID
    public let shareDate: Date
    public let permissions: CollaborationPermissions
}

public struct TaskSharingResult {
    public let task: Task
    public let sharedWith: [UUID]
    public let permissions: CollaborationPermissions
    public let shareDate: Date
}

public struct CollectionSharingResult {
    public let collection: TaskCollection
    public let tasks: [Task]
    public let sharedWith: [UUID]
    public let permissions: CollaborationPermissions
}

public struct TaskAssignmentResult {
    public let task: Task
    public let assignedUser: UUID
    public let assignmentDate: Date
}

public struct TaskCollaborationInfo {
    public let taskId: UUID
    public let collaborators: [Collaborator]
    public let permissions: [UUID: CollaborationPermissions]
    public let createdDate: Date
}

public struct Collaborator {
    public let userId: UUID
    public let name: String
    public let email: String
    public let permissions: CollaborationPermissions
}

public struct TaskAssignment {
    public let taskId: UUID
    public let assignedUserId: UUID
    public let assignedDate: Date
    public let deadline: Date?
}

public struct AssignmentRule {
    public let type: AssignmentRuleType
    public let condition: String
    public let assignedUserId: UUID
}

public struct TeamTaskTemplate {
    public let id: UUID
    public let name: String
    public let tasks: [CreateTaskRequest]
    public let assignmentRules: [AssignmentRule]
    public let createdDate: Date
}

public struct CollaborativeSession {
    public let id: UUID
    public let taskId: UUID
    public let startTime: Date
    public var participants: [UUID]
    public let isActive: Bool
}

public struct CollaborativeSessionSummary {
    public let sessionId: UUID
    public let taskId: UUID?
    public let duration: TimeInterval
    public let participants: [UUID]
    public let activitiesCount: Int
}

public struct TaskComment {
    public let id: UUID
    public let taskId: UUID
    public let content: String
    public let authorId: UUID
    public let createdDate: Date
    public let mentionedUsers: [UUID]
}

public struct CollaborationActivity {
    public let id: UUID
    public let taskId: UUID
    public let userId: UUID
    public let activityType: ActivityType
    public let details: String?
    public let timestamp: Date
}

public struct TaskSharingRecord {
    public let taskId: UUID
    public let sharedWithUsers: [UUID]
    public let permissions: CollaborationPermissions
    public let shareDate: Date
    public let message: String?
}

public struct CollectionSharingRecord {
    public let collectionId: UUID
    public let sharedWithUsers: [UUID]
    public let permissions: CollaborationPermissions
    public let shareDate: Date
}

public struct TaskCollection {
    public let id: UUID
    public let name: String
    public let taskIds: [UUID]
    public let createdDate: Date
}



// MARK: - Enums

public enum CollaborationPermissions: String, CaseIterable {
    case view = "view"
    case edit = "edit"
    case fullAccess = "full_access"
    
    public var description: String {
        switch self {
        case .view: return "View Only"
        case .edit: return "Edit"
        case .fullAccess: return "Full Access"
        }
    }
}

public enum AssignmentRuleType {
    case priority
    case category
    case deadline
    case workload
}

public enum ActivityType: String {
    case viewed = "viewed"
    case edited = "edited"
    case commented = "commented"
    case completed = "completed"
    case assigned = "assigned"
    case shared = "shared"
}



// MARK: - Error Types

public enum CollaborationError: LocalizedError {
    case repositoryError(Error)
    case userNotFound
    case taskNotFound
    case multipleTasksNotFound
    case permissionDenied
    case invalidCollaborationData
    case sessionNotFound
    
    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .userNotFound:
            return "User not found"
        case .taskNotFound:
            return "Task not found"
        case .multipleTasksNotFound:
            return "One or more tasks not found"
        case .permissionDenied:
            return "Permission denied for collaboration action"
        case .invalidCollaborationData:
            return "Invalid collaboration data provided"
        case .sessionNotFound:
            return "Collaborative session not found"
        }
    }
}



// MARK: - Protocol Definitions

public protocol CollaborationRepositoryProtocol {
    func fetchSharedTasks(completion: @escaping (Result<[SharedTask], Error>) -> Void)
    func fetchTasksSharedByUser(completion: @escaping (Result<[SharedTask], Error>) -> Void)
    func updatePermissions(taskId: UUID, userId: UUID, permissions: CollaborationPermissions, completion: @escaping (Result<Void, Error>) -> Void)
    func revokeAccess(taskId: UUID, userId: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchCollaborationInfo(taskId: UUID, completion: @escaping (Result<TaskCollaborationInfo, Error>) -> Void)
    func saveTaskAssignment(_ assignment: TaskAssignment, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchTeamAssignments(completion: @escaping (Result<[TaskAssignment], Error>) -> Void)
    func saveTeamTemplate(_ template: TeamTaskTemplate, completion: @escaping (Result<Void, Error>) -> Void)
    func saveCollaborativeSession(_ session: CollaborativeSession, completion: @escaping (Result<Void, Error>) -> Void)
    func joinSession(sessionId: UUID, completion: @escaping (Result<CollaborativeSession, Error>) -> Void)
    func endSession(sessionId: UUID, completion: @escaping (Result<CollaborativeSessionSummary, Error>) -> Void)
    func saveComment(_ comment: TaskComment, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchComments(taskId: UUID, completion: @escaping (Result<[TaskComment], Error>) -> Void)
    func updateComment(commentId: UUID, content: String, completion: @escaping (Result<TaskComment, Error>) -> Void)
    func fetchActivity(taskId: UUID, completion: @escaping (Result<[CollaborationActivity], Error>) -> Void)
    func saveActivity(_ activity: CollaborationActivity, completion: @escaping (Result<Void, Error>) -> Void)
    func saveTaskSharing(_ record: TaskSharingRecord, completion: @escaping (Result<Void, Error>) -> Void)
    func saveTaskCollection(_ collection: TaskCollection, completion: @escaping (Result<Void, Error>) -> Void)
    func saveCollectionSharing(_ record: CollectionSharingRecord, completion: @escaping (Result<Void, Error>) -> Void)
}

