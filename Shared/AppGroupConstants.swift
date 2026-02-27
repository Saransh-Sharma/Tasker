import Foundation

public enum AppGroupConstants {
    public static let suiteName = "group.com.saransh1337.tasker.shared"
    public static let snapshotFileName = "GamificationWidgetSnapshot.json"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }

    public static var snapshotURL: URL? {
        containerURL?.appendingPathComponent(snapshotFileName)
    }
}
