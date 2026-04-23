import SwiftUI
import SwiftData

struct WatchlistView: View {
    @EnvironmentObject private var engine: QuoteEngine
    @Environment(\.modelContext) private var context
    @Query(sort: \WatchedSymbol.sortOrder) private var symbols: [WatchedSymbol]

    @State private var newSymbol: String = ""
    @State private var alertTarget: String?
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Watchlist").font(.headline)
                Spacer()
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
            }

            HStack {
                TextField("Add symbol (e.g. AAPL)", text: $newSymbol)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addSymbol)
                Button("Add", action: addSymbol)
                    .disabled(newSymbol.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if symbols.isEmpty {
                Text("No symbols yet. Add one above.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                List {
                    ForEach(symbols) { item in
                        row(for: item)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            context.delete(symbols[index])
                        }
                        try? context.save()
                    }
                }
                .frame(minHeight: 200)
            }

            Divider()
            Button("Quit Stock Alerts") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(width: 320)
        .sheet(item: Binding(
            get: { alertTarget.map(AlertTargetWrapper.init) },
            set: { alertTarget = $0?.symbol }
        )) { wrapper in
            AlertEditorView(symbol: wrapper.symbol)
        }
    }

    @ViewBuilder
    private func row(for item: WatchedSymbol) -> some View {
        HStack {
            Text(item.symbol).fontWeight(.medium)
            Spacer()
            if let quote = engine.quotes[item.symbol] {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f", quote.price)).monospacedDigit()
                    Text(String(format: "%+.2f%%", quote.changePercent))
                        .font(.caption)
                        .foregroundStyle(quote.changePercent >= 0 ? .green : .red)
                        .monospacedDigit()
                }
            } else {
                Text("—").foregroundStyle(.secondary)
            }
            Button {
                alertTarget = item.symbol
            } label: {
                Image(systemName: "bell")
            }
            .buttonStyle(.borderless)
        }
    }

    private func addSymbol() {
        let trimmed = newSymbol.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let store = WatchlistStore(context: context)
        store.add(trimmed)
        newSymbol = ""
    }
}

private struct AlertTargetWrapper: Identifiable {
    let symbol: String
    var id: String { symbol }
}
