import Testing
import Foundation
import SwiftData
import Domain
import Application
import Adapters
@testable import StockAlerts

@MainActor
struct QuoteEngineViewModelTests {
    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        let pair = try TestHelpers.makeInMemoryContainer()
        self.container = pair.container
        self.context = pair.context
    }

    private func quote(_ symbol: String, _ price: Double) -> Quote {
        Quote(symbol: symbol, price: price, previousClose: 100, open: price, high: price, low: price,
              timestamp: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private struct Harness {
        let viewModel: QuoteEngineViewModel
        let alerts: SwiftDataAlertRepository
        let watchlist: SwiftDataWatchlistRepository
        let engine: QuoteEngine
    }

    private func makeHarness(quotes: [Quote] = []) -> Harness {
        let alerts = SwiftDataAlertRepository(context: context)
        let watchlist = SwiftDataWatchlistRepository(context: context)
        let engine = QuoteEngine(
            service: StubQuoteService(quotes),
            alertRepository: alerts,
            watchlistRepository: watchlist,
            notifications: NoopNotificationScheduler(),
            isMarketOpen: { true }
        )
        let vm = QuoteEngineViewModel(engine: engine, alertRepository: alerts, watchlistRepository: watchlist)
        return Harness(viewModel: vm, alerts: alerts, watchlist: watchlist, engine: engine)
    }

    // MARK: - the regression: a poll-fired alert must update the published alerts list

    @Test
    func tick_firingAnAlert_updatesPublishedAlerts() async {
        let h = makeHarness(quotes: [quote("AAPL", 150)])
        h.watchlist.add("AAPL")
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 100)
        h.alerts.add(alert)
        h.viewModel.refresh()
        #expect(h.viewModel.alerts.first(where: { $0.id == alert.id })?.isTriggered == false)

        // tick() fires the alert (markTriggered) and emits onStateChange. The
        // published `alerts` list must reflect the fired state — on main this
        // came free from SwiftData @Query.
        await h.engine.tick()

        #expect(h.viewModel.alerts.first(where: { $0.id == alert.id })?.isTriggered == true)
    }

    // MARK: - mutation methods keep the published lists consistent

    @Test
    func addSymbol_appearsInWatchlist() {
        let h = makeHarness()
        h.viewModel.addSymbol("aapl")
        #expect(h.viewModel.watchlist.map(\.symbol) == ["AAPL"])
    }

    @Test
    func removeSymbol_dropsIt() {
        let h = makeHarness()
        h.viewModel.addSymbol("AAPL")
        h.viewModel.addSymbol("MSFT")
        h.viewModel.removeSymbol("AAPL")
        #expect(h.viewModel.watchlist.map(\.symbol) == ["MSFT"])
    }

    @Test
    func addAlert_thenRemoveAlert() {
        let h = makeHarness()
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 1)
        h.viewModel.addAlert(alert)
        #expect(h.viewModel.alerts.contains { $0.id == alert.id })
        h.viewModel.removeAlert(id: alert.id)
        #expect(!h.viewModel.alerts.contains { $0.id == alert.id })
    }

    @Test
    func resetAlert_clearsTriggeredState() {
        let h = makeHarness()
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 1)
        h.viewModel.addAlert(alert)
        h.alerts.markTriggered(id: alert.id)
        h.viewModel.refresh()
        #expect(h.viewModel.alerts.first?.isTriggered == true)
        h.viewModel.resetAlert(id: alert.id)
        #expect(h.viewModel.alerts.first?.isTriggered == false)
    }
}

// MARK: - minimal test doubles (the package fakes live in the package test target)

private actor StubQuoteService: QuoteService {
    private let quotes: [Quote]
    init(_ quotes: [Quote]) { self.quotes = quotes }
    func fetchQuote(symbol: String) async throws -> Quote {
        guard let q = quotes.first(where: { $0.symbol == symbol }) else { throw QuoteServiceError.invalidSymbol(symbol) }
        return q
    }
    func fetchQuotes(symbols: [String]) async throws -> [Quote] { quotes }
}

private final class NoopNotificationScheduler: NotificationScheduler, @unchecked Sendable {
    func schedule(id: String, title: String, body: String) async {}
}
