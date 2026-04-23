import Foundation
import UserNotifications

enum NotificationAuthorizer {
    /// Requests alert+sound permission. Safe to call repeatedly; macOS caches
    /// the user's decision after the first prompt.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
