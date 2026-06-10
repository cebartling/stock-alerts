import SwiftUI
import SwiftData
import Domain
import Application
import Adapters

@main
struct StockAlertsApp: App {
    // Retained for the app's lifetime so the repositories' main context stays
    // valid (ModelContext only weakly references its container).
    private let container: ModelContainer
    @StateObject private var viewModel: QuoteEngineViewModel
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
            notifications: UNUserNotificationScheduler(),
            isMarketOpen: {
                let extended = UserDefaults.standard.bool(forKey: DefaultsKey.extendedHours)
                return MarketClock.isOpen(at: .now, extended: extended)
            }
        )
        engine.pollInterval = TimeInterval(
            max(10, UserDefaults.standard.integer(forKey: DefaultsKey.pollIntervalSeconds))
        )
        _viewModel = StateObject(wrappedValue: QuoteEngineViewModel(
            engine: engine,
            alertRepository: alertRepository,
            watchlistRepository: watchlistRepository
        ))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(viewModel)
                .task {
                    await NotificationAuthorizer.requestAuthorization()
                    if powerObserver == nil {
                        powerObserver = PowerObserver(
                            onSleep: { viewModel.stop() },
                            onWake: { viewModel.start() }
                        )
                    }
                    viewModel.start()
                }
        } label: {
            MenuBarLabel()
                .environmentObject(viewModel)
        }
        .menuBarExtraStyle(.window)

        Window("Stock Alerts", id: "main") {
            MainWindowView()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 800, height: 520)

        Settings {
            SettingsView()
                .environmentObject(viewModel)
        }
    }
}
