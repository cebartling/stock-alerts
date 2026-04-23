import SwiftUI
import SwiftData

struct AlertEditorView: View {
    let symbol: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allAlerts: [PriceAlert]

    @State private var condition: PriceAlert.Condition = .above
    @State private var thresholdText: String = ""

    private var alerts: [PriceAlert] {
        allAlerts.filter { $0.symbol == symbol.uppercased() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alerts for \(symbol.uppercased())").font(.headline)

            if alerts.isEmpty {
                Text("No alerts for this symbol yet.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(alerts) { alert in
                        HStack {
                            Text(label(for: alert))
                                .strikethrough(alert.isTriggered)
                            Spacer()
                            if alert.isTriggered {
                                Text("fired").foregroundStyle(.secondary).font(.caption)
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
                    }
                }
                .frame(minHeight: 120)
            }

            Divider()
            Text("New alert").font(.subheadline)

            Picker("Condition", selection: $condition) {
                Text("Price above").tag(PriceAlert.Condition.above)
                Text("Price below").tag(PriceAlert.Condition.below)
                Text("% change up").tag(PriceAlert.Condition.percentChangeUp)
                Text("% change down").tag(PriceAlert.Condition.percentChangeDown)
            }
            .pickerStyle(.menu)

            TextField("Threshold", text: $thresholdText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add alert") { addAlert() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(Double(thresholdText) == nil)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private func label(for alert: PriceAlert) -> String {
        switch alert.condition {
        case .above:             return "above \(String(format: "%.2f", alert.threshold))"
        case .below:             return "below \(String(format: "%.2f", alert.threshold))"
        case .percentChangeUp:   return "+\(String(format: "%.2f", alert.threshold))%"
        case .percentChangeDown: return "-\(String(format: "%.2f", abs(alert.threshold)))%"
        }
    }

    private func addAlert() {
        guard let value = Double(thresholdText) else { return }
        let store = AlertStore(context: context)
        store.add(PriceAlert(symbol: symbol, condition: condition, threshold: value))
        dismiss()
    }
}
