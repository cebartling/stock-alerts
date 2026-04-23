import Foundation
import UserNotifications

protocol NotificationScheduler: Sendable {
    func schedule(id: String, title: String, body: String) async
}

struct UNUserNotificationScheduler: NotificationScheduler {
    func schedule(id: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
