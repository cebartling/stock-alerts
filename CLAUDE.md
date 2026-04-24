# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

All shell commands are run from the repo root.

- **Run tests**: `./scripts/test.sh` — wraps `xcodebuild test` with the flags this project needs every time (Debug, `platform=macOS,arch=arm64`, `-allowProvisioningUpdates`). Extra args forward to `xcodebuild`.
- **Run one suite / one test**: `./scripts/test.sh -only-testing:StockAlertsTests/KeychainStoreTests` or `-only-testing:StockAlertsTests/KeychainStoreTests/writeThenRead_roundTrips`.
- **Regenerate the `.xcodeproj`**: `xcodegen generate`. `StockAlerts.xcodeproj/` is gitignored and built from `project.yml`. **You must re-run `xcodegen generate` after adding, removing, or renaming any source file** — new files aren't part of the project until regeneration, even if the build appears to succeed from a stale project.
- **Open in Xcode**: `open StockAlerts.xcodeproj` (requires `Local.xcconfig` — see README for setup).

## TDD is required for all code changes

Red → Green → Refactor is the working style for every non-UI code change in this repo. Write a failing test first, implement the minimum code to pass, then refactor. This includes bug fixes and small tweaks, not just new features.

**Only exception: SwiftUI views.** They're smoke-tested manually in the running app. When you're about to change a view, say so up front and describe the manual smoke test — don't just make the change. The subprocess-based `writes_doNotPolluteLoginKeychainFile` test is the pattern for testing anything that escapes the process boundary; in-process SecItem queries can't discriminate DPK from legacy storage once `keychain-access-groups` is entitled.

## Architecture

A SwiftUI + SwiftData macOS menu bar app. Three scenes in `StockAlertsApp`:

1. `MenuBarExtra { MenuBarPopoverView() }` — always-present ticker popover with an "Open Stock Alerts" button.
2. `Window("Stock Alerts", id: "main") { MainWindowView() }` — single-instance main window (`NavigationSplitView` sidebar + `SymbolDetailView`). Opened via `@Environment(\.openWindow)` from the popover, paired with `NSApp.activate(ignoringOtherApps: true)` so it becomes frontmost despite `LSUIElement=YES`.
3. `Settings { SettingsView() }` — macOS Settings scene; opened from the popover's gear via `SettingsLink`.

The engine is a single `@MainActor` `ObservableObject` held as a `@StateObject` on `StockAlertsApp`:

```
WatchlistStore  ─────┐
                     ▼
                QuoteEngine ──(polls)── QuoteService protocol ── FinnhubQuoteService
                  │  │                                          (actor, URLSession)
                  │  └─ alerts(for:) / markTriggered ──── AlertStore
                  │
                  └─ schedule notifications ── NotificationScheduler protocol
                                              └── UNUserNotificationScheduler (prod)
```

Critical injection seams that exist **only** so tests can replace them. Do not collapse:

- `QuoteService` protocol — production `FinnhubQuoteService`; tests use `FakeQuoteService` / `ToggleableQuoteService` / `GenericThrowingQuoteService` in `QuoteEngineTests.swift`.
- `NotificationScheduler` protocol — production wraps `UNUserNotificationCenter`; tests use `FakeNotificationScheduler`.
- `isMarketOpen: @Sendable () -> Bool` closure passed into `QuoteEngine.init` — production reads `UserDefaults "extendedHours"` + `MarketClock.isOpen`; tests inject a fixed `{ true }` / `{ false }`.

`FinnhubQuoteService` takes `session: URLSession = .shared` in its init specifically so tests can pass a `URLSession` backed by the `StubURLProtocol` subclass in `StockAlertsTests/StubURLProtocol.swift` — that's how the Finnhub service is unit tested without the network.

### SwiftData

Models: `WatchedSymbol` (watchlist entries with `sortOrder`), `PriceAlert` (alert rows with condition + threshold). Both live under `StockAlerts/Models/`.

`WatchlistStore` and `AlertStore` (both `@MainActor` classes in `StockAlerts/Stores/`) are the only way the engine mutates SwiftData. Route state changes through the stores, not through direct `context.insert`/`.delete` — `AlertStore.markTriggered` exists specifically so the engine never touches `@Model` properties directly.

**Gotcha: `ModelContext` only weakly references its `ModelContainer`.** If a helper or factory returns just a context and the owning container deallocates, the next `context.fetch` / `.save` traps inside SwiftData with `EXC_BREAKPOINT` and a "type metadata for `<ModelType>`" frame. `StockAlertsTests/TestHelpers.swift:makeInMemoryContainer()` returns `(container, context)` and test suites store both as `let` properties to keep the container alive for the whole test. In `StockAlertsApp` the container is held as a `private let` on the `App` struct.

### Keychain / Secrets

`KeychainStore` routes every `SecItem*` call through `kSecUseDataProtectionKeychain: true`. The app declares `keychain-access-groups` in its entitlements for this to work, which means the app **must be signed with a real development certificate** — ad-hoc signing fails at codesign-time. The team ID is read from the gitignored `Local.xcconfig`.

`Secrets.finnhubKey` is the production read/write wrapper for the Finnhub API key. Tests use UUID-scoped service names via `makeStore()` in `KeychainStoreTests.swift` to isolate.

### Polling and power

`QuoteEngine.start()` launches a `Task` loop that calls `tick()` and sleeps `pollInterval` seconds. `tick()` gates on `isMarketOpen()` (injected closure) and skips if the watchlist is empty. `PowerObserver` (`StockAlerts/Power/PowerObserver.swift`) wires `NSWorkspace.willSleepNotification` → `engine.stop()` and `didWakeNotification` → `engine.start()` — this is the only reason the app has a `PowerObserver` field on `StockAlertsApp`.

## Signing and entitlements

Signing is non-negotiable because `keychain-access-groups` requires development signing, not ad-hoc. `Local.xcconfig` supplies `DEVELOPMENT_TEAM`; it's gitignored with `Local.xcconfig.example` committed as the template. If `Local.xcconfig` is missing, `scripts/test.sh` exits with a helpful message; if `xcodebuild test` is invoked directly without `-allowProvisioningUpdates`, signing fails with "No profiles for …".

Any entitlement change goes through `project.yml` (under `targets.StockAlerts.entitlements.properties`), not by hand-editing `StockAlerts.entitlements` — the file is regenerated on every `xcodegen generate`.

## SourceKit diagnostics

SourceKit's background indexer regularly emits false-positive `Cannot find type 'X' in scope` errors on newly added files across module boundaries (e.g. test files that `@testable import StockAlerts`). These almost never reflect reality — trust the `xcodebuild` result, not the in-editor diagnostic. If a build via `scripts/test.sh` succeeds, ignore the red squiggles; they'll clear after the next indexer pass.


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
