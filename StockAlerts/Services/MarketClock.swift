import Foundation

// NYSE holiday calendar is intentionally not handled in v1; closed-day polls
// are cheap and just waste a few API calls per year.
enum MarketClock {
    static func isOpen(at date: Date, extended: Bool = false) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let comps = cal.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = comps.weekday, (2...6).contains(weekday) else { return false }
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let open  = extended ? 4 * 60      : 9 * 60 + 30   // 4:00 or 9:30 ET
        let close = extended ? 20 * 60     : 16 * 60       // 20:00 or 16:00 ET
        return minutes >= open && minutes < close
    }
}
