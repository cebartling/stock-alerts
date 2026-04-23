import SwiftUI

@main
struct StockAlertsApp: App {
    var body: some Scene {
        MenuBarExtra("Stocks", systemImage: "chart.line.uptrend.xyaxis") {
            Text("Stock Alerts")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
