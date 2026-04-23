import Testing
import Foundation
@testable import StockAlerts

struct MarketClockTests {

    private static let et: TimeZone = TimeZone(identifier: "America/New_York")!

    /// Build an ET date for a given weekday (1=Sun, 2=Mon, ..., 7=Sat) at h:m.
    /// Anchors on a known Monday (2026-04-20) to seed a weekday search.
    private func etDate(weekday: Int, hour: Int, minute: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.et
        // Start from a Monday in ET: 2026-04-20
        var base = DateComponents()
        base.year = 2026; base.month = 4; base.day = 20
        base.hour = hour; base.minute = minute
        let monday = cal.date(from: base)!
        // weekday argument: 1=Sun ... 7=Sat. Monday=2.
        let offset = weekday - 2
        return cal.date(byAdding: .day, value: offset, to: monday)!
    }

    // MARK: - weekends

    @Test
    func saturdayRegular_isClosed() {
        let d = etDate(weekday: 7, hour: 10, minute: 0) // Sat 10:00 ET
        #expect(MarketClock.isOpen(at: d, extended: false) == false)
    }

    @Test
    func saturdayExtended_isClosed() {
        let d = etDate(weekday: 7, hour: 10, minute: 0)
        #expect(MarketClock.isOpen(at: d, extended: true) == false)
    }

    @Test
    func sundayRegular_isClosed() {
        let d = etDate(weekday: 1, hour: 10, minute: 0) // Sun 10:00 ET
        #expect(MarketClock.isOpen(at: d, extended: false) == false)
    }

    // MARK: - weekdays, regular hours

    @Test
    func mondayTenAMRegular_isOpen() {
        let d = etDate(weekday: 2, hour: 10, minute: 0)
        #expect(MarketClock.isOpen(at: d, extended: false) == true)
    }

    @Test
    func weekdayNineTwentyNineRegular_isClosed() {
        // One minute before regular open
        let d = etDate(weekday: 3, hour: 9, minute: 29)
        #expect(MarketClock.isOpen(at: d, extended: false) == false)
    }

    @Test
    func weekdayNineThirtyRegular_isOpen() {
        let d = etDate(weekday: 3, hour: 9, minute: 30)
        #expect(MarketClock.isOpen(at: d, extended: false) == true)
    }

    @Test
    func weekdaySixteenZeroRegular_isClosed() {
        // Exactly at close (16:00); SPEC uses `minutes < close` so this is closed.
        let d = etDate(weekday: 4, hour: 16, minute: 0)
        #expect(MarketClock.isOpen(at: d, extended: false) == false)
    }

    @Test
    func weekdayFifteenFiftyNineRegular_isOpen() {
        let d = etDate(weekday: 4, hour: 15, minute: 59)
        #expect(MarketClock.isOpen(at: d, extended: false) == true)
    }

    @Test
    func weekdayEightAMRegular_isClosed() {
        let d = etDate(weekday: 5, hour: 8, minute: 0)
        #expect(MarketClock.isOpen(at: d, extended: false) == false)
    }

    @Test
    func weekdaySixteenThirtyRegular_isClosed() {
        let d = etDate(weekday: 5, hour: 16, minute: 30)
        #expect(MarketClock.isOpen(at: d, extended: false) == false)
    }

    // MARK: - weekdays, extended hours

    @Test
    func weekdayEightAMExtended_isOpen() {
        let d = etDate(weekday: 3, hour: 8, minute: 0)
        #expect(MarketClock.isOpen(at: d, extended: true) == true)
    }

    @Test
    func weekdaySixteenThirtyExtended_isOpen() {
        let d = etDate(weekday: 3, hour: 16, minute: 30)
        #expect(MarketClock.isOpen(at: d, extended: true) == true)
    }

    @Test
    func weekdayThreeFiftyNineAMExtended_isClosed() {
        // Before extended open (04:00 ET)
        let d = etDate(weekday: 4, hour: 3, minute: 59)
        #expect(MarketClock.isOpen(at: d, extended: true) == false)
    }

    @Test
    func weekdayFourAMExtended_isOpen() {
        let d = etDate(weekday: 4, hour: 4, minute: 0)
        #expect(MarketClock.isOpen(at: d, extended: true) == true)
    }

    @Test
    func weekdayTwentyHundredExtended_isClosed() {
        // Exactly at extended close (20:00); `< close` means closed.
        let d = etDate(weekday: 4, hour: 20, minute: 0)
        #expect(MarketClock.isOpen(at: d, extended: true) == false)
    }
}
