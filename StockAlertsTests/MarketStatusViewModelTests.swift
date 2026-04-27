import Testing
import Foundation
@testable import StockAlerts

struct MarketStatusViewModelTests {

    private static let et: TimeZone = TimeZone(identifier: "America/New_York")!

    /// Build an ET date for a given weekday (1=Sun ... 7=Sat) at h:m,
    /// anchored on Mon 2026-04-20 ET (matches MarketClockTests' anchor).
    private func etDate(weekday: Int, hour: Int, minute: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.et
        var base = DateComponents()
        base.year = 2026; base.month = 4; base.day = 20
        base.hour = hour; base.minute = minute
        let monday = cal.date(from: base)!
        return cal.date(byAdding: .day, value: weekday - 2, to: monday)!
    }

    @Test
    func make_weekdayDuringRegularHours_isOpen() {
        let wed14 = etDate(weekday: 4, hour: 14, minute: 0)
        let model = MarketStatusViewModel.make(now: wed14, extended: false)
        #expect(model.isOpen == true)
        #expect(model.label == "Market Open")
    }

    @Test
    func make_onWeekend_isClosedRegardlessOfExtended() {
        let sat10 = etDate(weekday: 7, hour: 10, minute: 0)
        let regular = MarketStatusViewModel.make(now: sat10, extended: false)
        let extended = MarketStatusViewModel.make(now: sat10, extended: true)
        #expect(regular.isOpen == false)
        #expect(regular.label == "Market Closed")
        #expect(extended.isOpen == false)
        #expect(extended.label == "Market Closed")
    }

    @Test
    func make_extendedFlagFlipsResultIn0800ETPreMarketWindow() {
        // 08:00 ET on a weekday: regular hours are closed, extended is open.
        // This tests that the extended flag is forwarded correctly through
        // the view-model — i.e. it isn't silently dropped or hard-coded.
        let wed8 = etDate(weekday: 4, hour: 8, minute: 0)
        let regular = MarketStatusViewModel.make(now: wed8, extended: false)
        let extended = MarketStatusViewModel.make(now: wed8, extended: true)
        #expect(regular.isOpen == false)
        #expect(regular.label == "Market Closed")
        #expect(extended.isOpen == true)
        #expect(extended.label == "Market Open")
    }
}
