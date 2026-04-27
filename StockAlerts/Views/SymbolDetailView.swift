import SwiftUI
import SwiftData

struct SymbolDetailView: View {
    let symbol: String

    @EnvironmentObject private var engine: QuoteEngine
    @Environment(\.modelContext) private var context
    @Query private var allAlerts: [PriceAlert]
    @Query(sort: \WatchedSymbol.sortOrder) private var watched: [WatchedSymbol]

    @State private var newCondition: PriceAlert.Condition = .above
    @State private var newThresholdText: String = ""

    private var alerts: [PriceAlert] {
        let upper = symbol.uppercased()
        return allAlerts.filter { $0.symbol == upper }
    }

    private var quote: Quote? { engine.quotes[symbol.uppercased()] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                Divider()
                alertsSection
                Divider()
                newAlertSection
                Divider()
                Button(role: .destructive) {
                    let store = WatchlistStore(context: context)
                    store.remove(symbol)
                } label: {
                    Label("Remove from watchlist", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    StocksAppLauncher.shared.open(symbol: symbol)
                } label: {
                    Label("Open in Stocks", systemImage: "arrow.up.right.square")
                }
                .help("Open \(symbol.uppercased()) in Apple's Stocks app")
            }
        }
    }

    // MARK: - sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(symbol.uppercased())
                .font(.system(size: 36, weight: .semibold))
            if let q = quote {
                HStack(spacing: 12) {
                    Text(String(format: "%.2f", q.price))
                        .font(.system(size: 24, weight: .medium))
                        .monospacedDigit()
                    Text(String(format: "%+.2f (%+.2f%%)", q.changeAbsolute, q.changePercent))
                        .font(.system(size: 16))
                        .foregroundStyle(q.changePercent >= 0 ? .green : .red)
                        .monospacedDigit()
                }
                HStack(alignment: .top, spacing: 16) {
                    stat(label: "Open", value: q.open)
                    stat(label: "High", value: q.high)
                    stat(label: "Low", value: q.low)
                    stat(label: "Prev Close", value: q.previousClose)
                }
            } else {
                Text("Waiting for quote…")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stat(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(String(format: "%.2f", value))
                .font(.callout)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(String(format: "%.2f", value))")
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alerts").font(.title3).bold()
            if alerts.isEmpty {
                Text("No alerts for \(symbol.uppercased()).")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(alerts) { alert in
                    alertRow(alert)
                }
            }
        }
    }

    @ViewBuilder
    private func alertRow(_ alert: PriceAlert) -> some View {
        HStack {
            Text(label(for: alert))
                .strikethrough(alert.isTriggered)
            if alert.isTriggered {
                Text("fired")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.3))
                    .clipShape(Capsule())
            }
            Spacer()
            if alert.isTriggered {
                Button("Reset") {
                    let store = AlertStore(context: context)
                    store.reset(alert)
                }
                .buttonStyle(.borderless)
            }
            Button(role: .destructive) {
                let store = AlertStore(context: context)
                store.remove(alert)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var newAlertSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New alert").font(.title3).bold()
            HStack {
                Picker("Condition", selection: $newCondition) {
                    Text("Price above").tag(PriceAlert.Condition.above)
                    Text("Price below").tag(PriceAlert.Condition.below)
                    Text("% change up").tag(PriceAlert.Condition.percentChangeUp)
                    Text("% change down").tag(PriceAlert.Condition.percentChangeDown)
                }
                .pickerStyle(.menu)
                .labelsHidden()

                TextField("Threshold", text: $newThresholdText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)

                Button("Add alert") { addAlert() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(Double(newThresholdText) == nil)
            }
        }
    }

    // MARK: - helpers

    private func label(for alert: PriceAlert) -> String {
        switch alert.condition {
        case .above:             return "Price above \(String(format: "%.2f", alert.threshold))"
        case .below:             return "Price below \(String(format: "%.2f", alert.threshold))"
        case .percentChangeUp:   return "Up \(String(format: "%.2f", alert.threshold))%"
        case .percentChangeDown: return "Down \(String(format: "%.2f", abs(alert.threshold)))%"
        }
    }

    private func addAlert() {
        guard let value = Double(newThresholdText) else { return }
        let store = AlertStore(context: context)
        store.add(PriceAlert(symbol: symbol, condition: newCondition, threshold: value))
        newThresholdText = ""
    }
}
