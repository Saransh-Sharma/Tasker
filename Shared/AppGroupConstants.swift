import Foundation

public enum AppGroupConstants {
    public static let suiteName = "group.com.saransh1337.tasker.shared"
    public static let snapshotFileName = "GamificationWidgetSnapshot.json"
    public static let taskListSnapshotFileName = "TaskListWidgetSnapshot.json"
    public static let taskListSnapshotBackupFileName = "TaskListWidgetSnapshot.backup.json"
    public static let taskListActionCommandFileName = "TaskListWidgetActionCommand.json"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }

    public static var snapshotURL: URL? {
        containerURL?.appendingPathComponent(snapshotFileName)
    }

    public static var taskListSnapshotURL: URL? {
        containerURL?.appendingPathComponent(taskListSnapshotFileName)
    }

    public static var taskListSnapshotBackupURL: URL? {
        containerURL?.appendingPathComponent(taskListSnapshotBackupFileName)
    }

    public static var taskListActionCommandURL: URL? {
        containerURL?.appendingPathComponent(taskListActionCommandFileName)
    }
}
