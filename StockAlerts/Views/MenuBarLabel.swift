import SwiftUI

struct MenuBarLabel: View {
    var body: some View {
        // SF Symbol shares the chart-line glyph with the app icon for visual
        // continuity. SwiftUI renders Image(systemName:) as a template in
        // MenuBarExtra labels, so the system handles light/dark/focus tinting.
        HStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
            MarketStatusBadge(style: .compact)
        }
    }
}
