import SwiftUI

enum MarketStatusFormatter {
    static func text(isOpen: Bool) -> String {
        isOpen ? "Market Open" : "Market Closed"
    }
}

struct MarketStatusBadge: View {
    enum Style {
        case full
        case compact
    }

    let style: Style

    @AppStorage("extendedHours") private var extendedHours: Bool = false

    init(style: Style = .full) {
        self.style = style
    }

    var body: some View {
        switch style {
        case .full:
            TimelineView(.periodic(from: Date(), by: 30)) { context in
                content(isOpen: MarketClock.isOpen(at: context.date, extended: extendedHours))
            }
        case .compact:
            // TimelineView inside MenuBarExtra's label freezes the SwiftUI
            // runtime (kills xctest's runner-connect handshake). The status-bar
            // label re-renders on every QuoteEngine poll, so a static read here
            // gives the same effective cadence without TimelineView.
            content(isOpen: MarketClock.isOpen(at: Date(), extended: extendedHours))
        }
    }

    @ViewBuilder
    private func content(isOpen: Bool) -> some View {
        switch style {
        case .full:
            HStack(spacing: 6) {
                dot(isOpen: isOpen)
                Text(MarketStatusFormatter.text(isOpen: isOpen))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isOpen ? .primary : .secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(MarketStatusFormatter.text(isOpen: isOpen))
        case .compact:
            dot(isOpen: isOpen)
                .accessibilityLabel(MarketStatusFormatter.text(isOpen: isOpen))
        }
    }

    private func dot(isOpen: Bool) -> some View {
        Circle()
            .fill(isOpen ? Color.green : Color.secondary)
            .frame(width: 8, height: 8)
    }
}
