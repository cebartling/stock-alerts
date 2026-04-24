# ADR-0008: Poll Finnhub on a timer; no websocket

- **Status**: Accepted
- **Date**: 2026-04-23

## Context

Finnhub exposes both a REST quote endpoint and a streaming websocket tier. A websocket would give sub-second updates with no polling overhead, at the cost of a persistent connection, a reconnection strategy, and a $50/month plan.

## Decision

`QuoteEngine` polls the REST endpoint on a fixed interval. Default 30 s; configurable in Settings from 10–300 s in 5 s steps. `QuoteEngine.start()` launches a `Task` that alternates `await tick()` / `await Task.sleep(for: .seconds(pollInterval))`.

Polling is gated by two conditions so idle cost is near-zero:

- `isMarketOpen()` returns `false` outside NYSE hours — tick is a no-op.
- `watchlist.symbols.isEmpty` — tick short-circuits before any network call.

`PowerObserver` additionally stops the engine on `NSWorkspace.willSleepNotification` and restarts it on `didWakeNotification`, so a sleeping Mac doesn't poll.

## Consequences

- Zero infrastructure: no websocket connection lifecycle, no heartbeat, no reconnect-on-network-flap logic.
- Free-tier Finnhub works fine. At 30 s intervals with 5 watched symbols during market hours, daily API usage is well under any free-tier cap.
- Near-real-time but not tick-accurate. For a personal watchlist this is fine; day-trading use cases are explicitly out of scope.
- The `QuoteService` protocol abstracts the transport, so a future websocket implementation could be dropped in without touching the engine if that ever becomes a real need.

## Alternatives considered

- **Websocket streaming**: higher fidelity but monthly cost and persistent-connection complexity that doesn't pay off for the target user (personal watchlist).
- **Shorter poll intervals (e.g. 5 s)**: no meaningful UX gain for a menu-bar indicator, 6× the API usage, still not tick-accurate.
