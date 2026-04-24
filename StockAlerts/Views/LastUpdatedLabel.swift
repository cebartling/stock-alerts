import SwiftUI

enum LastUpdatedFormatter {
    static func text(now: Date, since: Date?) -> String {
        guard let since else { return "—" }
        let elapsed = max(0, now.timeIntervalSince(since))
        if elapsed < 60 {
            return "Updated \(Int(elapsed))s ago"
        }
        if elapsed < 3600 {
            return "Updated \(Int(elapsed / 60))m ago"
        }
        return "Updated at \(since.formatted(date: .omitted, time: .shortened))"
    }
}

struct LastUpdatedLabel: View {
    let date: Date?

    var body: some View {
        if let date {
            TimelineView(.periodic(from: date, by: 5)) { context in
                Text(LastUpdatedFormatter.text(now: context.date, since: date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } else {
            Text(LastUpdatedFormatter.text(now: Date(), since: nil))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
