import SwiftUI
import SwiftData
import Domain
import Adapters

@main
struct StockAlertsApp: App {
    private let container: ModelContainer
    @StateObject private var engine: QuoteEngine
    @State private var powerObserver: PowerObserver?

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: SymbolRecord.self, AlertRecord.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        self.container = container

        let alertRepository = SwiftDataAlertRepository(context: container.mainContext)
        let watchlistRepository = SwiftDataWatchlistRepository(context: container.mainContext)
        let service = FinnhubQuoteService(apiKey: Secrets.finnhubKey)
        let engine = QuoteEngine(
            service: service,
            alertRepository: alertRepository,
            watchlistRepository: watchlistRepository,
            isMarketOpen: {
                let extended = UserDefaults.standard.bool(forKey: DefaultsKey.extendedHours)
                return MarketClock.isOpen(at: .now, extended: extended)
            }
        )
        engine.pollInterval = TimeInterval(
            max(10, UserDefaults.standard.integer(forKey: DefaultsKey.pollIntervalSeconds))
        )
        _engine = StateObject(wrappedValue: engine)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
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

        Window("Stock Alerts", id: "main") {
            MainWindowView()
                .environmentObject(engine)
                .modelContainer(container)
        }
        .defaultSize(width: 800, height: 520)

        Settings {
            SettingsView()
                .environmentObject(engine)
        }
    }
}
