import SwiftUI
import SwiftData

struct MenuBarLabel: View {
    @EnvironmentObject private var engine: QuoteEngine
    @Query(sort: \WatchedSymbol.sortOrder) private var symbols: [WatchedSymbol]

    var body: some View {
        // SF Symbol shares the chart-line glyph with the app icon for visual
        // continuity. SwiftUI renders Image(systemName:) as a template in
        // MenuBarExtra labels, so the system handles light/dark/focus tinting.
        if let primary = symbols.first, let quote = engine.quotes[primary.symbol] {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                MarketStatusBadge(style: .compact)
                Text(primary.symbol).fontWeight(.medium)
                Text(String(format: "%.2f", quote.price)).monospacedDigit()
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                MarketStatusBadge(style: .compact)
            }
        }
    }
}
