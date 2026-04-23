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

    @Test
    func tick_nonQuoteServiceError_wrappedAsNetwork() async {
        let watchlist = WatchlistStore(context: context)
        watchlist.add("AAPL")
        let alertStore = AlertStore(context: context)
        let service = GenericThrowingQuoteService(error: URLError(.notConnectedToInternet))
        let engine = QuoteEngine(
            service: service,
            alertStore: alertStore,
            watchlistStore: watchlist,
            notifications: FakeNotificationScheduler(),
            isMarketOpen: { true }
        )

        await engine.tick()

        if case .network(let underlying) = engine.lastError,
           let urlError = underlying as? URLError {
            #expect(urlError.code == .notConnectedToInternet)
        } else {
            Issue.record("Expected .network wrapping URLError, got \(String(describing: engine.lastError))")
        }
    }

    // MARK: - multiple alerts / multiple symbols

    @Test
    func tick_multipleAlertsOnSameSymbol_firesEachMatchIndependently() async {
        let watchlist = WatchlistStore(context: context)
        watchlist.add("AAPL")
        let alertStore = AlertStore(context: context)
        let above100 = PriceAlert(symbol: "AAPL", condition: .above, threshold: 100)
        let above160 = PriceAlert(symbol: "AAPL", condition: .above, threshold: 160)
        let above200 = PriceAlert(symbol: "AAPL", condition: .above, threshold: 200)
        alertStore.add(above100)
        alertStore.add(above160)
        alertStore.add(above200)

        // Price 170 straddles the thresholds: 170>=100 ✓, 170>=160 ✓, 170>=200 ✗.
        let service = FakeQuoteService(result: .success([makeQuote("AAPL", price: 170)]))
        let scheduler = FakeNotificationScheduler()
        let engine = QuoteEngine(
            service: service,
            alertStore: alertStore,
            watchlistStore: watchlist,
            notifications: scheduler,
            isMarketOpen: { true }
        )

        await engine.tick()

        #expect(scheduler.scheduled.count == 2)
        let firedIds = Set(scheduler.scheduled.map(\.id))
        #expect(firedIds.contains(above100.id.uuidString))
        #expect(firedIds.contains(above160.id.uuidString))
        #expect(!firedIds.contains(above200.id.uuidString))
        #expect(above100.isTriggered == true)
        #expect(above160.isTriggered == true)
        #expect(above200.isTriggered == false)
    }

    @Test
    func tick_multipleSymbols_onlyMatchingOnesFireAlerts() async {
        let watchlist = WatchlistStore(context: context)
        watchlist.add("AAPL")
        watchlist.add("MSFT")
        let alertStore = AlertStore(context: context)
        let aaplAlert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 100)
        let msftAlert = PriceAlert(symbol: "MSFT", condition: .below, threshold: 50)  // won't match
        alertStore.add(aaplAlert)
        alertStore.add(msftAlert)

        let service = FakeQuoteService(result: .success([
            makeQuote("AAPL", price: 200),
            makeQuote("MSFT", price: 300),
        ]))
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
        #expect(scheduler.scheduled.first?.id == aaplAlert.id.uuidString)
        #expect(aaplAlert.isTriggered == true)
        #expect(msftAlert.isTriggered == false)
    }

    @Test
    func tick_successAfterError_clearsLastError() async {
        let watchlist = WatchlistStore(context: context)
        watchlist.add("AAPL")
        let alertStore = AlertStore(context: context)
        let scheduler = FakeNotificationScheduler()
        let service = ToggleableQuoteService(initialResult: .failure(.rateLimited))
        let engine = QuoteEngine(
            service: service,
            alertStore: alertStore,
            watchlistStore: watchlist,
            notifications: scheduler,
            isMarketOpen: { true }
        )

        // First tick fails — lastError is set.
        await engine.tick()
        #expect(engine.lastError != nil)

        // Flip the service to return a valid quote and tick again.
        await service.setResult(.success([makeQuote("AAPL", price: 100)]))
        await engine.tick()

        #expect(engine.lastError == nil)
        #expect(engine.quotes["AAPL"]?.price == 100)
    }

    @Test
    func tick_populatesQuoteCacheEvenWhenNoAlertMatches() async {
        let watchlist = WatchlistStore(context: context)
        watchlist.add("AAPL")
        let (engine, scheduler, _) = makeEngine(
            quotes: .success([makeQuote("AAPL", price: 150)])
        )

        await engine.tick()

        #expect(engine.quotes["AAPL"]?.price == 150)
        #expect(scheduler.scheduled.isEmpty)
    }
}

// Secondary fake used only by the non-QuoteServiceError test. The main
// FakeQuoteService is parameterized on QuoteServiceError, so this one covers
// the path where the service throws anything else.
actor GenericThrowingQuoteService: QuoteService {
    private let error: Error
    init(error: Error) { self.error = error }
    func fetchQuote(symbol: String) async throws -> Quote { throw error }
    func fetchQuotes(symbols: [String]) async throws -> [Quote] { throw error }
}

// Lets a test flip between success and failure across ticks.
actor ToggleableQuoteService: QuoteService {
    private var result: Result<[Quote], QuoteServiceError>

    init(initialResult: Result<[Quote], QuoteServiceError>) {
        self.result = initialResult
    }

    func setResult(_ newResult: Result<[Quote], QuoteServiceError>) {
        result = newResult
    }

    func fetchQuote(symbol: String) async throws -> Quote {
        switch result {
        case .success(let quotes):
            if let q = quotes.first(where: { $0.symbol == symbol }) { return q }
            throw QuoteServiceError.invalidSymbol(symbol)
        case .failure(let err): throw err
        }
    }

    func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        switch result {
        case .success(let quotes): return quotes
        case .failure(let err): throw err
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
