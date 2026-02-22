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
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
            }
        }
    }

    /// Always posts asynchronously on the main queue to avoid adding work to the current UI event turn.
    static func postAsyncOnMain(
        name: Notification.Name,
        object: Any? = nil,
        userInfo: [AnyHashable: Any]? = nil
    ) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
        }
    }
}
