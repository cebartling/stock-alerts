import SwiftUI
import SwiftData
import Adapters

struct MenuBarPopoverView: View {
    @EnvironmentObject private var engine: QuoteEngine
    @Environment(\.openWindow) private var openWindow
    // Interim: reads stay on @Query for live updates; the clean view-model swap
    // lands in Phase 4. Writes already route through the repository ports.
    @Query(sort: \SymbolRecord.sortOrder) private var symbols: [SymbolRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Watchlist").font(.headline)
                    Spacer()
                    SettingsLink {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.borderless)
                }
                MarketStatusBadge(style: .full)
            }

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Open Stock Alerts")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Divider()

            if symbols.isEmpty {
                Text("No symbols yet.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(symbols) { item in
                        row(for: item)
                    }
                }
            }

            Divider()
            HStack {
                LastUpdatedLabel(date: engine.lastSuccessfulFetch)
                Spacer()
                Button("Quit Stock Alerts") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    @ViewBuilder
    private func row(for item: SymbolRecord) -> some View {
        HStack {
            Text(item.symbol).fontWeight(.medium)
            Spacer()
            if let quote = engine.quotes[item.symbol] {
                Text(String(format: "%.2f", quote.price)).monospacedDigit()
                Text(String(format: "%+.2f%%", quote.changePercent))
                    .font(.caption)
                    .foregroundStyle(quote.changePercent >= 0 ? .green : .red)
                    .monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }
}
