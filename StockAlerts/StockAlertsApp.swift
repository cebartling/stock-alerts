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
    #if DEBUG
    // Dev-only HTTP control server, started at launch (not in the MenuBarExtra
    // content's .task, which only runs when the popover is first opened).
    private let devServer: DevHTTPServer?
    #endif

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
        let viewModel = QuoteEngineViewModel(
            engine: engine,
            alertRepository: alertRepository,
            watchlistRepository: watchlistRepository
        )
        _viewModel = StateObject(wrappedValue: viewModel)

        #if DEBUG
        let server = DevHTTPServer(surface: AppDevControlSurface(viewModel: viewModel))
        try? server.start()
        devServer = server
        #endif
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
