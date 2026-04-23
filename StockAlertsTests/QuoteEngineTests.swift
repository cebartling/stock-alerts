import Testing
import Foundation
import SwiftData
@testable import StockAlerts

@MainActor
struct QuoteEngineTests {
    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        let pair = try TestHelpers.makeInMemoryContainer()
        self.container = pair.container
        self.context = pair.context
    }

    // MARK: - helpers

    private func makeQuote(_ symbol: String, price: Double, prevClose: Double = 100) -> Quote {
        Quote(
            symbol: symbol,
            price: price,
            previousClose: prevClose,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func makeEngine(
        quotes: Result<[Quote], QuoteServiceError> = .success([]),
        isMarketOpen: @escaping @Sendable () -> Bool = { true }
    ) -> (engine: QuoteEngine, scheduler: FakeNotificationScheduler, service: FakeQuoteService) {
        let service = FakeQuoteService(result: quotes)
        let scheduler = FakeNotificationScheduler()
        let alertStore = AlertStore(context: context)
        let watchlistStore = WatchlistStore(context: context)
        let engine = QuoteEngine(
            service: service,
            alertStore: alertStore,
            watchlistStore: watchlistStore,
            notifications: scheduler,
            isMarketOpen: isMarketOpen
        )
        return (engine, scheduler, service)
    }

    // MARK: - market hours gating

    @Test
    func tick_outsideMarketHours_doesNothing() async {
        let watchlist = WatchlistStore(context: context)
        watchlist.add("AAPL")
        let (engine, scheduler, _) = makeEngine(
            quotes: .success([makeQuote("AAPL", price: 123)]),
            isMarketOpen: { false }
        )
        await engine.tick()
        #expect(engine.quotes.isEmpty)
        #expect(scheduler.scheduled.isEmpty)
    }

    @Test
    func tick_duringMarketHours_emptyWatchlist_skipsFetch() async {
        // No watched symbols; should not call service at all and not populate quotes.
        let (engine, _, service) = makeEngine(quotes: .success([makeQuote("AAPL", price: 1)]))
        await engine.tick()
        #expect(engine.quotes.isEmpty)
        let callCount = await service.callCount
        #expect(callCount == 0)
    }

    // MARK: - quote population

    @Test
    func tick_populatesQuotesByCaching() async {
        let watchlist = WatchlistStore(context: context)
        watchlist.add("AAPL")
        watchlist.add("MSFT")
        let (engine, _, _) = makeEngine(
            quotes: .success([
                makeQuote("AAPL", price: 111),
                makeQuote("MSFT", price: 222),
            ])
        )
        await engine.tick()
        #expect(engine.quotes["AAPL"]?.price == 111)
        #expect(engine.quotes["MSFT"]?.price == 222)
    }

    // MARK: - alerts

    @Test
    func tick_firesMatchingAlert() async {
        let watchlist = WatchlistStore(context: context)
        watchlist.add("AAPL")
        let alertStore = AlertStore(context: context)
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 100)
        alertStore.add(alert)

        let service = FakeQuoteService(result: .success([makeQuote("AAPL", price: 150)]))
        let scheduler = FakeNotificationScheduler()
        let engine = QuoteEngine(
            service: service,
            alertStore: alertStore,
            watchlistStore: watchlist,
            notifications: scheduler,
            isMarketOpen: { true }
        )

        await engine.tick()

        #expect(scheduler.scheduled.count == 1)
        #expect(scheduler.scheduled.first?.id == alert.id.uuidString)
        #expect(alert.isTriggered == true)
        #expect(alert.triggeredAt != nil)
    }

    @Test
    func tick_nonMatchingAlert_doesNotFire() async {
        let watchlist = WatchlistStore(context: context)
        watchlist.add("AAPL")
        let alertStore = AlertStore(context: context)
        alertStore.add(PriceAlert(symbol: "AAPL", condition: .above, threshold: 200))

        let (engine, scheduler, _) = makeEngine(
            quotes: .success([makeQuote("AAPL", price: 150)])
        )

        await engine.tick()

        #expect(scheduler.scheduled.isEmpty)
    }

    @Test
    func tick_alreadyTriggeredAlert_doesNotRefire() async {
        let watchlist = WatchlistStore(context: context)
        watchlist.add("AAPL")
        let alertStore = AlertStore(context: context)
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 100)
        alertStore.add(alert)
        alertStore.markTriggered(alert)

        let service = FakeQuoteService(result: .success([makeQuote("AAPL", price: 150)]))
        let scheduler = FakeNotificationScheduler()
        let engine = QuoteEngine(
            service: service,
            alertStore: alertStore,
            watchlistStore: watchlist,
            notifications: scheduler,
            isMarketOpen: { true }
        )

        await engine.tick()

        #expect(scheduler.scheduled.isEmpty)
    }

    // MARK: - errors

    @Test
    func tick_serviceError_capturedAsLastError() async {
        let watchlist = WatchlistStore(context: context)
        watchlist.add("AAPL")
        let (engine, _, _) = makeEngine(quotes: .failure(.rateLimited))

        await engine.tick()

        if case .rateLimited = engine.lastError {
            // ok
        } else {
            Issue.record("Expected rateLimited, got \(String(describing: engine.lastError))")
        }
    }
}

// MARK: - Test doubles

final class FakeNotificationScheduler: NotificationScheduler, @unchecked Sendable {
    private let lock = NSLock()
    private var _scheduled: [(id: String, title: String, body: String)] = []

    var scheduled: [(id: String, title: String, body: String)] {
        lock.lock(); defer { lock.unlock() }
        return _scheduled
    }

    func schedule(id: String, title: String, body: String) async {
        lock.lock(); defer { lock.unlock() }
        _scheduled.append((id, title, body))
    }
}

actor FakeQuoteService: QuoteService {
    private let result: Result<[Quote], QuoteServiceError>
    private(set) var callCount = 0

    init(result: Result<[Quote], QuoteServiceError>) {
        self.result = result
    }

    func fetchQuote(symbol: String) async throws -> Quote {
        callCount += 1
        switch result {
        case .success(let quotes):
            if let q = quotes.first(where: { $0.symbol == symbol }) { return q }
            throw QuoteServiceError.invalidSymbol(symbol)
        case .failure(let err):
            throw err
        }
    }

    func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        callCount += 1
        switch result {
        case .success(let quotes): return quotes
        case .failure(let err): throw err
        }
    }
}
