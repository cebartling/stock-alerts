# ADR-0003: Red/Green TDD is the default workflow

- **Status**: Accepted
- **Date**: 2026-04-23

## Context

The project was bootstrapped from a comprehensive spec, and the initial plan grouped tests under a late "polish" phase. This was explicitly rejected at plan-review time: tests should drive implementation, not follow it.

## Decision

Every non-UI code change in this repo starts with a failing test (red), followed by the minimum implementation that makes it pass (green), followed by an optional refactor. This applies to new features, bug fixes, refactors, and small tweaks — not only to greenfield development.

UI views — anything under `StockAlerts/Views/` plus `MenuBarLabel`, `StockAlertsApp`'s scene wiring, and platform-permission dialogs — are the explicit exception. They're smoke-tested manually by running the app. When a contributor proposes a UI change, they call out the exception up front and describe the manual smoke test; they do not silently skip.

## Consequences

- Every production change arrives with a test that would have failed against the unchanged code. This forced surface-area decisions that would otherwise be skipped (e.g., the injection seams in [ADR-0006](0006-quote-engine-injection-seams.md)).
- Characterization tests for existing code are acceptable — if a new test passes on first run against existing production code, coverage is still legitimately added.
- When a non-UI behavior is genuinely unreachable from in-process tests (rare; example: the on-disk keychain discriminator in `writes_doNotPolluteLoginKeychainFile`), the test author uses the next-best mechanism (subprocess, filesystem probe) and documents why.
- Because tests gate every file, the `xcodebuild` / `scripts/test.sh` loop is the fastest feedback loop in the repo; SourceKit diagnostics in Xcode are treated as advisory only (see `CLAUDE.md`).

## Alternatives considered

- **Tests as a late phase (original plan)**: rejected. Defers the forcing function that makes injection seams and separation of concerns feel cheap; makes retrofitting tests onto existing code expensive.
- **Test-after with coverage thresholds**: functionally similar outcome but loses the design-pressure benefit of red-first.
