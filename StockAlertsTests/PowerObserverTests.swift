import Testing
import Foundation
import AppKit
@testable import StockAlerts

@MainActor
struct PowerObserverTests {

    @Test
    func sleepNotification_invokesOnSleep()  {
        nonisolated(unsafe) var sleepCount = 0
        nonisolated(unsafe) var wakeCount = 0

        let observer = PowerObserver(
            onSleep: { sleepCount += 1 },
            onWake: { wakeCount += 1 }
        )
        _ = observer  // keep alive

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.willSleepNotification,
            object: NSWorkspace.shared
        )

        #expect(sleepCount == 1)
        #expect(wakeCount == 0)
    }

    @Test
    func wakeNotification_invokesOnWake() {
        nonisolated(unsafe) var sleepCount = 0
        nonisolated(unsafe) var wakeCount = 0

        let observer = PowerObserver(
            onSleep: { sleepCount += 1 },
            onWake: { wakeCount += 1 }
        )
        _ = observer

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didWakeNotification,
            object: NSWorkspace.shared
        )

        #expect(sleepCount == 0)
        #expect(wakeCount == 1)
    }

    @Test
    func deinitRemovesObservers() {
        nonisolated(unsafe) var sleepCount = 0

        do {
            let observer = PowerObserver(
                onSleep: { sleepCount += 1 },
                onWake: {}
            )
            _ = observer
        }
        // Observer deallocated — posting the notification should not increment.
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.willSleepNotification,
            object: NSWorkspace.shared
        )
        #expect(sleepCount == 0)
    }
}
