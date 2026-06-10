import Foundation

/// Driven port for delivering user notifications. The application core depends
/// on this abstraction; a UserNotifications-backed adapter conforms.
public protocol NotificationScheduler: Sendable {
    func schedule(id: String, title: String, body: String) async
}
