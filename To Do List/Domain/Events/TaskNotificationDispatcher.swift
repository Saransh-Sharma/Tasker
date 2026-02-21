import Foundation

enum TaskNotificationDispatcher {
    /// Executes postOnMain.
    static func postOnMain(
        name: Notification.Name,
        object: Any? = nil,
        userInfo: [AnyHashable: Any]? = nil
    ) {
        if Foundation.Thread.current.isMainThread {
            NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
        } else {
            DispatchQueue.main.sync {
                NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
            }
        }
    }
}
