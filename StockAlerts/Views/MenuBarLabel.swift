import SwiftUI
import SwiftData

struct MenuBarLabel: View {
    @EnvironmentObject private var engine: QuoteEngine
    @Query(sort: \WatchedSymbol.sortOrder) private var symbols: [WatchedSymbol]

    var body: some View {
        if let primary = symbols.first, let quote = engine.quotes[primary.symbol] {
            HStack(spacing: 4) {
                Text(primary.symbol).fontWeight(.medium)
                Text(String(format: "%.2f", quote.price)).monospacedDigit()
            }
        } else {
            Text("Stocks")
        }
    }
}
