import Foundation
import AppKit

/// Bridges macOS sleep/wake notifications to callbacks, so the app can pause
/// polling on sleep and resume on wake.
@MainActor
public final class PowerObserver {
    private var sleepToken: NSObjectProtocol?
    private var wakeToken: NSObjectProtocol?

    public init(onSleep: @escaping @MainActor () -> Void, onWake: @escaping @MainActor () -> Void) {
        let center = NSWorkspace.shared.notificationCenter
        sleepToken = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { onSleep() }
        }
        wakeToken = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { onWake() }
        }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        if let sleepToken { center.removeObserver(sleepToken) }
        if let wakeToken { center.removeObserver(wakeToken) }
    }
}
