import Testing
import Foundation
import Domain
@testable import StockAlerts

@MainActor
struct QuoteEngineTests {

    // MARK: - helpers

    private func makeQuote(_ symbol: String, price: Double, prevClose: Double = 100) -> Quote {
        Quote(
            symbol: symbol,
            price: price,
            previousClose: prevClose,
            open: price,
            high: price,
            low: price,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private struct Harness {
        let engine: QuoteEngine
        let scheduler: FakeNotificationScheduler
        let service: FakeQuoteService
        let alerts: FakeAlertRepository
        let watchlist: FakeWatchlistRepository
    }

    private func makeEngine(
        quotes: Result<[Quote], QuoteServiceError> = .success([]),
        isMarketOpen: @escaping @Sendable () -> Bool = { true },
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> Harness {
        let service = FakeQuoteService(result: quotes)
        let scheduler = FakeNotificationScheduler()
        let alerts = FakeAlertRepository()
        let watchlist = FakeWatchlistRepository()
        let engine = QuoteEngine(
            service: service,
            alertRepository: alerts,
            watchlistRepository: watchlist,
            notifications: scheduler,
            isMarketOpen: isMarketOpen,
            now: now
        )
        return Harness(engine: engine, scheduler: scheduler, service: service, alerts: alerts, watchlist: watchlist)
    }

    /// Re-fetch an alert's triggered state from the repository (value types
    /// mean the local copy passed to `add` never mutates).
    private func isTriggered(_ id: UUID, in repo: FakeAlertRepository, symbol: String) -> Bool {
        repo.alerts(for: symbol).first { $0.id == id }?.isTriggered ?? false
    }

    // MARK: - market hours gating

    @Test
    func tick_outsideMarketHours_doesNothing() async {
        let h = makeEngine(
            quotes: .success([makeQuote("AAPL", price: 123)]),
            isMarketOpen: { false }
        )
        h.watchlist.add("AAPL")
        await h.engine.tick()
        #expect(h.engine.quotes.isEmpty)
        #expect(h.scheduler.scheduled.isEmpty)
    }

    @Test
    func tick_duringMarketHours_emptyWatchlist_skipsFetch() async {
        // No watched symbols; should not call service at all and not populate quotes.
        let h = makeEngine(quotes: .success([makeQuote("AAPL", price: 1)]))
        await h.engine.tick()
        #expect(h.engine.quotes.isEmpty)
        let callCount = await h.service.callCount
        #expect(callCount == 0)
    }

    // MARK: - quote population

    @Test
    func tick_populatesQuotesByCaching() async {
        let h = makeEngine(
            quotes: .success([
                makeQuote("AAPL", price: 111),
                makeQuote("MSFT", price: 222),
            ])
        )
        h.watchlist.add("AAPL")
        h.watchlist.add("MSFT")
        await h.engine.tick()
        #expect(h.engine.quotes["AAPL"]?.price == 111)
        #expect(h.engine.quotes["MSFT"]?.price == 222)
    }

    // MARK: - alerts

    @Test
    func tick_firesMatchingAlert() async {
        let h = makeEngine(quotes: .success([makeQuote("AAPL", price: 150)]))
        h.watchlist.add("AAPL")
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 100)
        h.alerts.add(alert)

        await h.engine.tick()

        #expect(h.scheduler.scheduled.count == 1)
        #expect(h.scheduler.scheduled.first?.id == alert.id.uuidString)
        let fired = h.alerts.alerts(for: "AAPL").first { $0.id == alert.id }
        #expect(fired?.isTriggered == true)
        #expect(fired?.triggeredAt != nil)
    }

    @Test
    func tick_nonMatchingAlert_doesNotFire() async {
        let h = makeEngine(quotes: .success([makeQuote("AAPL", price: 150)]))
        h.watchlist.add("AAPL")
        h.alerts.add(PriceAlert(symbol: "AAPL", condition: .above, threshold: 200))

        await h.engine.tick()

        #expect(h.scheduler.scheduled.isEmpty)
    }

    @Test
    func tick_alreadyTriggeredAlert_doesNotRefire() async {
        let h = makeEngine(quotes: .success([makeQuote("AAPL", price: 150)]))
        h.watchlist.add("AAPL")
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 100)
        h.alerts.add(alert)
        h.alerts.markTriggered(id: alert.id)

        await h.engine.tick()

        #expect(h.scheduler.scheduled.isEmpty)
    }

    // MARK: - errors

    @Test
    func tick_serviceError_capturedAsLastError() async {
        let h = makeEngine(quotes: .failure(.rateLimited))
        h.watchlist.add("AAPL")

        await h.engine.tick()

        if case .rateLimited = h.engine.lastError {
            // ok
        } else {
            Issue.record("Expected rateLimited, got \(String(describing: h.engine.lastError))")
        }
    }

    @Test
    func tick_nonQuoteServiceError_wrappedAsNetwork() async {
        let watchlist = FakeWatchlistRepository()
        watchlist.add("AAPL")
        let service = GenericThrowingQuoteService(error: URLError(.notConnectedToInternet))
        let engine = QuoteEngine(
            service: service,
            alertRepository: FakeAlertRepository(),
            watchlistRepository: watchlist,
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
        let h = makeEngine(quotes: .success([makeQuote("AAPL", price: 170)]))
        h.watchlist.add("AAPL")
        let above100 = PriceAlert(symbol: "AAPL", condition: .above, threshold: 100)
        let above160 = PriceAlert(symbol: "AAPL", condition: .above, threshold: 160)
        let above200 = PriceAlert(symbol: "AAPL", condition: .above, threshold: 200)
        h.alerts.add(above100)
        h.alerts.add(above160)
        h.alerts.add(above200)

        // Price 170 straddles the thresholds: 170>=100 ✓, 170>=160 ✓, 170>=200 ✗.
        await h.engine.tick()

        #expect(h.scheduler.scheduled.count == 2)
        let firedIds = Set(h.scheduler.scheduled.map(\.id))
        #expect(firedIds.contains(above100.id.uuidString))
        #expect(firedIds.contains(above160.id.uuidString))
        #expect(!firedIds.contains(above200.id.uuidString))
        #expect(isTriggered(above100.id, in: h.alerts, symbol: "AAPL") == true)
        #expect(isTriggered(above160.id, in: h.alerts, symbol: "AAPL") == true)
        #expect(isTriggered(above200.id, in: h.alerts, symbol: "AAPL") == false)
    }

    @Test
    func tick_multipleSymbols_onlyMatchingOnesFireAlerts() async {
        let h = makeEngine(quotes: .success([
            makeQuote("AAPL", price: 200),
            makeQuote("MSFT", price: 300),
        ]))
        h.watchlist.add("AAPL")
        h.watchlist.add("MSFT")
        let aaplAlert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 100)
        let msftAlert = PriceAlert(symbol: "MSFT", condition: .below, threshold: 50)  // won't match
        h.alerts.add(aaplAlert)
        h.alerts.add(msftAlert)

        await h.engine.tick()

        #expect(h.scheduler.scheduled.count == 1)
        #expect(h.scheduler.scheduled.first?.id == aaplAlert.id.uuidString)
        #expect(isTriggered(aaplAlert.id, in: h.alerts, symbol: "AAPL") == true)
        #expect(isTriggered(msftAlert.id, in: h.alerts, symbol: "MSFT") == false)
    }

    @Test
    func tick_successAfterError_clearsLastError() async {
        let watchlist = FakeWatchlistRepository()
        watchlist.add("AAPL")
        let service = ToggleableQuoteService(initialResult: .failure(.rateLimited))
        let engine = QuoteEngine(
            service: service,
            alertRepository: FakeAlertRepository(),
            watchlistRepository: watchlist,
            notifications: FakeNotificationScheduler(),
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

    // MARK: - lastSuccessfulFetch timestamp

    @Test
    func lastSuccessfulFetch_isNil_beforeFirstTick() {
        let h = makeEngine()
        #expect(h.engine.lastSuccessfulFetch == nil)
    }

    @Test
    func tick_setsLastSuccessfulFetch_onSuccess() async {
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        let h = makeEngine(
            quotes: .success([makeQuote("AAPL", price: 100)]),
            now: { fixed }
        )
        h.watchlist.add("AAPL")

        await h.engine.tick()

        #expect(h.engine.lastSuccessfulFetch == fixed)
    }

    @Test
    func tick_preservesLastSuccessfulFetch_acrossErrorAfterSuccess() async {
        let watchlist = FakeWatchlistRepository()
        watchlist.add("AAPL")
        let service = ToggleableQuoteService(
            initialResult: .success([makeQuote("AAPL", price: 100)])
        )
        let firstSuccess = Date(timeIntervalSince1970: 1_700_000_000)
        nonisolated(unsafe) var nowValue = firstSuccess
        let engine = QuoteEngine(
            service: service,
            alertRepository: FakeAlertRepository(),
            watchlistRepository: watchlist,
            notifications: FakeNotificationScheduler(),
            isMarketOpen: { true },
            now: { nowValue }
        )

        await engine.tick()
        #expect(engine.lastSuccessfulFetch == firstSuccess)

        // Move clock forward and have the next tick fail; timestamp must NOT regress or clear.
        nowValue = firstSuccess.addingTimeInterval(60)
        await service.setResult(.failure(.rateLimited))
        await engine.tick()

        #expect(engine.lastError != nil)
        #expect(engine.lastSuccessfulFetch == firstSuccess)
    }

    @Test
    func tick_outsideMarketHours_doesNotSetLastSuccessfulFetch() async {
        let h = makeEngine(
            quotes: .success([makeQuote("AAPL", price: 100)]),
            isMarketOpen: { false },
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        h.watchlist.add("AAPL")

        await h.engine.tick()

        #expect(h.engine.lastSuccessfulFetch == nil)
    }

    @Test
    func tick_emptyWatchlist_doesNotSetLastSuccessfulFetch() async {
        // No symbols added — service is never called, so a fetch did not actually happen.
        let h = makeEngine(
            quotes: .success([]),
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        await h.engine.tick()

        #expect(h.engine.lastSuccessfulFetch == nil)
    }

    @Test
    func tick_populatesQuoteCacheEvenWhenNoAlertMatches() async {
        let h = makeEngine(quotes: .success([makeQuote("AAPL", price: 150)]))
        h.watchlist.add("AAPL")

        await h.engine.tick()

        #expect(h.engine.quotes["AAPL"]?.price == 150)
        #expect(h.scheduler.scheduled.isEmpty)
    }

    // MARK: - clockTick (UI re-render heartbeat)

    @Test
    func clockTick_initializedFromNowClosure() {
        let fixed = Date(timeIntervalSince1970: 1_800_000_000)
        let h = makeEngine(now: { fixed })
        #expect(h.engine.clockTick == fixed)
    }

    @Test
    func tickClock_advancesClockTickToCurrentNow() {
        nonisolated(unsafe) var nowValue = Date(timeIntervalSince1970: 1_800_000_000)
        let h = makeEngine(now: { nowValue })
        nowValue = Date(timeIntervalSince1970: 1_800_000_060)
        h.engine.tickClock()
        #expect(h.engine.clockTick == Date(timeIntervalSince1970: 1_800_000_060))
    }

    @Test
    func tickClock_runsRegardlessOfMarketHours() {
        // The whole point: this heartbeat must fire even when the market is
        // closed, so views like MenuBarLabel re-render at the open boundary.
        nonisolated(unsafe) var nowValue = Date(timeIntervalSince1970: 1_800_000_000)
        let h = makeEngine(
            isMarketOpen: { false },
            now: { nowValue }
        )
        nowValue = Date(timeIntervalSince1970: 1_800_000_060)
        h.engine.tickClock()
        #expect(h.engine.clockTick == Date(timeIntervalSince1970: 1_800_000_060))
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
