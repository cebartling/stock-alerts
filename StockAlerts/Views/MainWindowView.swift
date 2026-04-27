import SwiftUI
import SwiftData

struct MainWindowView: View {
    @EnvironmentObject private var engine: QuoteEngine
    @Environment(\.modelContext) private var context
    @Query(sort: \WatchedSymbol.sortOrder) private var symbols: [WatchedSymbol]

    @State private var selection: String?
    @State private var newSymbol: String = ""

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        } detail: {
            detail
        }
        .navigationTitle("Stock Alerts")
        .toolbar {
            ToolbarItem(placement: .principal) {
                MarketStatusBadge(style: .full)
            }
            ToolbarItem {
                Button {
                    Task { await engine.tick() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Fetch latest quotes now")
            }
        }
        .frame(minWidth: 640, minHeight: 400)
    }

    // MARK: - sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section("Watchlist") {
                    ForEach(symbols) { item in
                        sidebarRow(item)
                            .tag(item.symbol)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            context.delete(symbols[index])
                        }
                        try? context.save()
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                TextField("Add symbol (e.g. AAPL)", text: $newSymbol)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addSymbol)
                Button("Add", action: addSymbol)
                    .disabled(newSymbol.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            HStack {
                LastUpdatedLabel(date: engine.lastSuccessfulFetch)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func sidebarRow(_ item: WatchedSymbol) -> some View {
        HStack {
            Text(item.symbol).fontWeight(.medium)
            Spacer()
            if let q = engine.quotes[item.symbol] {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.2f", q.price))
                        .monospacedDigit()
                        .font(.callout)
                    Text(String(format: "%+.2f%%", q.changePercent))
                        .font(.caption)
                        .foregroundStyle(q.changePercent >= 0 ? .green : .red)
                        .monospacedDigit()
                }
            } else {
                Text("—").foregroundStyle(.secondary).font(.caption)
            }
        }
    }

    // MARK: - detail

    @ViewBuilder
    private var detail: some View {
        if let symbol = selection {
            SymbolDetailView(symbol: symbol)
                .id(symbol)
        } else {
            ContentUnavailableView(
                "Select a symbol",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Pick a symbol from the sidebar to view its price and manage alerts.")
            )
        }
    }

    // MARK: - actions

    private func addSymbol() {
        let trimmed = newSymbol.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let store = WatchlistStore(context: context)
        store.add(trimmed)
        newSymbol = ""
    }
}
