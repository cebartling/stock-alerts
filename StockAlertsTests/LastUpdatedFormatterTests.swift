import Testing
import Foundation
@testable import StockAlerts

struct LastUpdatedFormatterTests {

    private let anchor = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func nilDate_rendersDash() {
        #expect(LastUpdatedFormatter.text(now: anchor, since: nil) == "—")
    }

    @Test
    func zeroElapsed_rendersZeroSecondsAgo() {
        let result = LastUpdatedFormatter.text(now: anchor, since: anchor)
        #expect(result == "Updated 0s ago")
    }

    @Test
    func sub60Seconds_rendersSecondsAgo() {
        let twelveAgo = anchor.addingTimeInterval(-12)
        let result = LastUpdatedFormatter.text(now: anchor, since: twelveAgo)
        #expect(result == "Updated 12s ago")
    }

    @Test
    func exactly60Seconds_switchesToMinutesFormat() {
        let oneMinAgo = anchor.addingTimeInterval(-60)
        let result = LastUpdatedFormatter.text(now: anchor, since: oneMinAgo)
        #expect(result == "Updated 1m ago")
    }

    @Test
    func under1Hour_rendersMinutesAgo() {
        let fortyTwoMinAgo = anchor.addingTimeInterval(-(42 * 60))
        let result = LastUpdatedFormatter.text(now: anchor, since: fortyTwoMinAgo)
        #expect(result == "Updated 42m ago")
    }

    @Test
    func atOrOver1Hour_switchesToAbsoluteAtFormat() {
        let twoHoursAgo = anchor.addingTimeInterval(-(2 * 3600))
        let result = LastUpdatedFormatter.text(now: anchor, since: twoHoursAgo)
        #expect(result.hasPrefix("Updated at "))
    }

    @Test
    func futureDate_rendersZeroSecondsAgo() {
        // Clock skew shouldn't yield negative-time labels.
        let inFuture = anchor.addingTimeInterval(30)
        let result = LastUpdatedFormatter.text(now: anchor, since: inFuture)
        #expect(result == "Updated 0s ago")
    }
}
