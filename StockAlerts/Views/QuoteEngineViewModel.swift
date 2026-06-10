import SwiftUI
import Domain
import Application

/// SwiftUI driving adapter for the framework-free `QuoteEngine`. Mirrors the
/// engine's `EngineState` into `@Published` fields and exposes repository-backed
/// lists, refreshed after every mutation. This is where the loss of SwiftData's
/// `@Query` auto-refresh is handled (see PIN-149 R1): views observe this object,
/// and every write goes through a method that calls `refresh()`.
@MainActor
final class QuoteEngineViewModel: ObservableObject {
    @Published private(set) var quotes: [String: Quote] = [:]
    @Published private(set) var lastError: QuoteServiceError?
    @Published private(set) var lastSuccessfulFetch: Date?
    @Published private(set) var clockTick: Date
    @Published private(set) var watchlist: [WatchedSymbol] = []
    @Published private(set) var alerts: [PriceAlert] = []

    private let engine: QuoteEngine
    private let alertRepository: AlertRepository
    private let watchlistRepository: WatchlistRepository

    init(
        engine: QuoteEngine,
        alertRepository: AlertRepository,
        watchlistRepository: WatchlistRepository
    ) {
        self.engine = engine
        self.alertRepository = alertRepository
        self.watchlistRepository = watchlistRepository
        self.clockTick = engine.state.clockTick
        engine.onStateChange = { [weak self] state in
            guard let self else { return }
            self.quotes = state.quotes
            self.lastError = state.lastError
            self.lastSuccessfulFetch = state.lastSuccessfulFetch
            self.clockTick = state.clockTick
        }
        refresh()
    }

    // MARK: - engine lifecycle

    func start() { engine.start() }
    func stop() { engine.stop() }
    func tick() async { await engine.tick() }

    var pollInterval: TimeInterval {
        get { engine.pollInterval }
        set { engine.pollInterval = newValue }
    }

    // MARK: - watchlist mutations

    func addSymbol(_ symbol: String) {
        watchlistRepository.add(symbol)
        refresh()
    }

    func removeSymbol(_ symbol: String) {
        watchlistRepository.remove(symbol)
        refresh()
    }

    func removeSymbols(at offsets: IndexSet) {
        for index in offsets { watchlistRepository.remove(watchlist[index].symbol) }
        refresh()
    }

    // MARK: - alert mutations

    func addAlert(_ alert: PriceAlert) {
        alertRepository.add(alert)
        refresh()
    }

    func removeAlert(id: UUID) {
        alertRepository.remove(id: id)
        refresh()
    }

    func resetAlert(id: UUID) {
        alertRepository.reset(id: id)
        refresh()
    }

    /// Re-read the persisted lists. Called after every mutation in place of
    /// SwiftData's automatic `@Query` invalidation.
    func refresh() {
        watchlist = watchlistRepository.all()
        alerts = alertRepository.all()
    }
}
