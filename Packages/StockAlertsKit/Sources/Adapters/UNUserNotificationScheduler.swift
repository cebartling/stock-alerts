import Foundation
import UserNotifications
import Domain

/// Production `NotificationScheduler` adapter backed by UserNotifications.
public struct UNUserNotificationScheduler: NotificationScheduler {
    public init() {}

    public func schedule(id: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
