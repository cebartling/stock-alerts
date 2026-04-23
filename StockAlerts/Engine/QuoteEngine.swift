import Foundation
import SwiftUI

@MainActor
final class QuoteEngine: ObservableObject {
    @Published private(set) var quotes: [String: Quote] = [:]
    @Published private(set) var lastError: QuoteServiceError?

    private let service: QuoteService
    private let alertStore: AlertStore
    private let watchlistStore: WatchlistStore
    private let notifications: NotificationScheduler
    private let isMarketOpen: @Sendable () -> Bool
    private var pollTask: Task<Void, Never>?

    var pollInterval: TimeInterval = 30

    init(
        service: QuoteService,
        alertStore: AlertStore,
        watchlistStore: WatchlistStore,
        notifications: NotificationScheduler = UNUserNotificationScheduler(),
        isMarketOpen: @escaping @Sendable () -> Bool = { MarketClock.isOpen(at: .now) }
    ) {
        self.service = service
        self.alertStore = alertStore
        self.watchlistStore = watchlistStore
        self.notifications = notifications
        self.isMarketOpen = isMarketOpen
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                let interval = self?.pollInterval ?? 30
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() { pollTask?.cancel() }

    func tick() async {
        guard isMarketOpen() else { return }
        let symbols = watchlistStore.symbols
        guard !symbols.isEmpty else { return }

        do {
            let fetched = try await service.fetchQuotes(symbols: symbols)
            for quote in fetched { quotes[quote.symbol] = quote }
            lastError = nil
            await evaluateAlerts(quotes: fetched)
        } catch let error as QuoteServiceError {
            lastError = error
        } catch {
            lastError = .network(error)
        }
    }

    private func evaluateAlerts(quotes: [Quote]) async {
        for quote in quotes {
            for alert in alertStore.alerts(for: quote.symbol) where alert.evaluate(against: quote) {
                await notifications.schedule(
                    id: alert.id.uuidString,
                    title: "\(alert.symbol) alert",
                    body: "\(alert.symbol) is \(String(format: "%.2f", quote.price)) "
                        + "(\(String(format: "%+.2f%%", quote.changePercent)))"
                )
                alertStore.markTriggered(alert)
            }
        }
    }
}
