import SwiftUI

enum MarketStatusViewModel {
    static func make(now: Date, extended: Bool) -> (isOpen: Bool, label: String) {
        let isOpen = MarketClock.isOpen(at: now, extended: extended)
        let label = isOpen ? "Market Open" : "Market Closed"
        return (isOpen, label)
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
                let model = MarketStatusViewModel.make(now: context.date, extended: extendedHours)
                content(model: model)
            }
        case .compact:
            // TimelineView inside MenuBarExtra's label freezes the SwiftUI
            // runtime (kills xctest's runner-connect handshake). MenuBarLabel
            // observes QuoteEngine.clockTick (a 60s heartbeat published
            // unconditionally), so the dot still updates at the open/close
            // boundary without TimelineView.
            let model = MarketStatusViewModel.make(now: Date(), extended: extendedHours)
            content(model: model)
        }
    }

    @ViewBuilder
    private func content(model: (isOpen: Bool, label: String)) -> some View {
        switch style {
        case .full:
            HStack(spacing: 6) {
                dot(isOpen: model.isOpen)
                Text(model.label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(model.isOpen ? .primary : .secondary)
            }
            .padding(.leading, 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(model.label)
        case .compact:
            dot(isOpen: model.isOpen)
                .accessibilityElement()
                .accessibilityAddTraits(.isStaticText)
                .accessibilityLabel(model.label)
        }
    }

    @ViewBuilder
    private func dot(isOpen: Bool) -> some View {
        // Open: filled green disc. Closed: hollow gray ring. The shape
        // difference carries the open/closed cue independent of color so the
        // signal isn't lost for color-blind users (the .full style also has
        // text; the .compact menu-bar dot is shape-only).
        if isOpen {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        } else {
            Circle()
                .strokeBorder(Color.secondary, lineWidth: 1.5)
                .frame(width: 8, height: 8)
        }
    }
}
