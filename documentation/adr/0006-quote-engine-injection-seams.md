# ADR-0006: Dependency-injected seams on `QuoteEngine`

- **Status**: Accepted
- **Date**: 2026-04-23

## Context

`QuoteEngine` is the heart of the app: it polls an external API on a timer, mutates SwiftData, and schedules user-visible notifications. Three of its dependencies are awkward to exercise in unit tests if accessed directly:

- **Network**: `URLSession` calls out to Finnhub.
- **Notifications**: `UNUserNotificationCenter` requires user permission and fires real system notifications.
- **Clock / market hours**: `Date.now` and `MarketClock.isOpen` are static; tests can't simulate Monday 10:00 ET on a Saturday run.

Without explicit seams these three concerns would either leak into tests or force tests to stub Apple frameworks at a coarser granularity.

## Decision

`QuoteEngine.init` takes three injectable dependencies:

```swift
init(
    service: QuoteService,                                          // network
    alertStore: AlertStore,
    watchlistStore: WatchlistStore,
    notifications: NotificationScheduler = UNUserNotificationScheduler(),  // notifications
    isMarketOpen: @escaping @Sendable () -> Bool = { MarketClock.isOpen(at: .now) }  // clock
)
```

- `QuoteService` is a `Sendable` protocol; production conformer is `FinnhubQuoteService` (an `actor` wrapping `URLSession`). Tests use `FakeQuoteService`, `ToggleableQuoteService`, or `GenericThrowingQuoteService`.
- `NotificationScheduler` is a `Sendable` protocol; production conformer `UNUserNotificationScheduler` calls `UNUserNotificationCenter.current().add(...)`. Tests use `FakeNotificationScheduler` which records scheduled notifications in memory.
- `isMarketOpen` is a closure, not a property, so production can read the live `UserDefaults "extendedHours"` toggle on every call. Tests pass a fixed `{ true }` or `{ false }`.

Additionally, `FinnhubQuoteService.init` accepts `session: URLSession = .shared` so its own tests can pass a `URLSession` configured with `StockAlertsTests/StubURLProtocol.swift`.

## Consequences

- Production wiring in `StockAlertsApp.init` is slightly longer (explicit `isMarketOpen` closure) but still one straight-line call.
- Every meaningful engine behavior has a deterministic unit test. No networking, no permission dialogs, no time travel required.
- These seams are **structural**. Future refactors must preserve them — collapsing `isMarketOpen` back into a direct `MarketClock.isOpen(...)` call inside `tick()`, or hard-coding `UNUserNotificationCenter.current()`, would break the test suite and defeat [ADR-0003](0003-tdd-working-style.md).

## Alternatives considered

- **Static globals / singletons**: simpler wiring, untestable without swizzling. Rejected.
- **Subclass-to-override** pattern: Swift discourages it, and the engine is a `final class` for concurrency clarity.
- **Method-level injection** (pass dependencies into `tick(service:notifications:...)`): leaks into the polling loop and the `start()` API. Rejected.
