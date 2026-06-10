import Foundation
import Domain

/// Snapshot of everything the UI renders from the engine. A plain value type so
/// the core stays framework-free; a SwiftUI adapter mirrors it into @Published.
public struct EngineState {
    public var quotes: [String: Quote]
    public var lastError: QuoteServiceError?
    public var lastSuccessfulFetch: Date?
    public var clockTick: Date

    public init(
        quotes: [String: Quote] = [:],
        lastError: QuoteServiceError? = nil,
        lastSuccessfulFetch: Date? = nil,
        clockTick: Date
    ) {
        self.quotes = quotes
        self.lastError = lastError
        self.lastSuccessfulFetch = lastSuccessfulFetch
        self.clockTick = clockTick
    }
}

@MainActor
public final class QuoteEngine {
    /// Current state. Read directly; observe changes via `onStateChange`.
    public private(set) var state: EngineState
    /// Invoked on the main actor whenever `state` changes. The SwiftUI
    /// view-model adapter sets this to mirror state into its @Published fields.
    public var onStateChange: ((EngineState) -> Void)?

    private let service: QuoteService
    private let alertRepository: AlertRepository
    private let watchlistRepository: WatchlistRepository
    private let notifications: NotificationScheduler
    private let isMarketOpen: @Sendable () -> Bool
    private let now: @Sendable () -> Date
    private var pollTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?

    public var pollInterval: TimeInterval = 30
    public var clockInterval: TimeInterval = 60

    public init(
        service: QuoteService,
        alertRepository: AlertRepository,
        watchlistRepository: WatchlistRepository,
        notifications: NotificationScheduler,
        isMarketOpen: @escaping @Sendable () -> Bool = { MarketClock.isOpen(at: .now) },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        self.alertRepository = alertRepository
        self.watchlistRepository = watchlistRepository
        self.notifications = notifications
        self.isMarketOpen = isMarketOpen
        self.now = now
        self.state = EngineState(clockTick: now())
    }

    public func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                let interval = self?.pollInterval ?? 30
                try? await Task.sleep(for: .seconds(interval))
            }
        }

        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.tickClock()
                let interval = self?.clockInterval ?? 60
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        clockTask?.cancel()
    }

    public func tickClock() {
        state.clockTick = now()
        emit()
    }

    public func tick() async {
        guard isMarketOpen() else { return }
        let symbols = watchlistRepository.symbols
        guard !symbols.isEmpty else { return }

        do {
            let fetched = try await service.fetchQuotes(symbols: symbols)
            for quote in fetched { state.quotes[quote.symbol] = quote }
            state.lastError = nil
            state.lastSuccessfulFetch = now()
            await evaluateAlerts(quotes: fetched)
        } catch let error as QuoteServiceError {
            state.lastError = error
        } catch {
            state.lastError = .network(error)
        }
        emit()
    }

    private func emit() {
        onStateChange?(state)
    }

    private func evaluateAlerts(quotes: [Quote]) async {
        for quote in quotes {
            for alert in alertRepository.alerts(for: quote.symbol) where alert.evaluate(against: quote) {
                await notifications.schedule(
                    id: alert.id.uuidString,
                    title: "\(alert.symbol) alert",
                    body: "\(alert.symbol) is \(String(format: "%.2f", quote.price)) "
                        + "(\(String(format: "%+.2f%%", quote.changePercent)))"
                )
                alertRepository.markTriggered(id: alert.id)
            }
        }
    }
}
