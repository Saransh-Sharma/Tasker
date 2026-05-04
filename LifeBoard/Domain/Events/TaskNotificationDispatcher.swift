import Foundation

private final class TaskNotificationPostBox: NSObject {
    let name: Notification.Name
    let object: Any?
    let userInfo: [AnyHashable: Any]?

    init(name: Notification.Name, object: Any?, userInfo: [AnyHashable: Any]?) {
        self.name = name
        self.object = object
        self.userInfo = userInfo
    }

    @objc func post() {
        NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
    }
}

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
            // Never block caller queues on main-thread notification delivery.
            TaskNotificationPostBox(name: name, object: object, userInfo: userInfo)
                .performSelector(onMainThread: #selector(TaskNotificationPostBox.post), with: nil, waitUntilDone: false)
        }
    }
}
