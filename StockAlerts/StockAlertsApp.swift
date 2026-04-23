import SwiftUI
import SwiftData

@main
struct StockAlertsApp: App {
    private let container: ModelContainer
    @StateObject private var engine: QuoteEngine
    @State private var powerObserver: PowerObserver?

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: WatchedSymbol.self, PriceAlert.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        self.container = container

        let alertStore = AlertStore(context: container.mainContext)
        let watchlistStore = WatchlistStore(context: container.mainContext)
        let service = FinnhubQuoteService(apiKey: Secrets.finnhubKey)
        let engine = QuoteEngine(
            service: service,
            alertStore: alertStore,
            watchlistStore: watchlistStore,
            isMarketOpen: {
                let extended = UserDefaults.standard.bool(forKey: "extendedHours")
                return MarketClock.isOpen(at: .now, extended: extended)
            }
        )
        engine.pollInterval = TimeInterval(
            max(10, UserDefaults.standard.integer(forKey: "pollIntervalSeconds"))
        )
        _engine = StateObject(wrappedValue: engine)
    }

    var body: some Scene {
        MenuBarExtra {
            WatchlistView()
                .environmentObject(engine)
                .modelContainer(container)
                .task {
                    await NotificationAuthorizer.requestAuthorization()
                    if powerObserver == nil {
                        powerObserver = PowerObserver(
                            onSleep: { engine.stop() },
                            onWake: { engine.start() }
                        )
                    }
                    engine.start()
                }
        } label: {
            MenuBarLabel()
                .environmentObject(engine)
                .modelContainer(container)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(engine)
        }
    }
}
