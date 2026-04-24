# Architecture Decision Records

Short records of load-bearing decisions in the Stock Alerts codebase. Format follows Michael Nygard's ADR template: **Context → Decision → Status → Consequences** (plus **Alternatives considered** where a real trade-off was made).

ADRs are immutable once merged. If a later decision overrides an earlier one, add a new ADR and mark the old one **Superseded by ADR-NNNN** in its *Status* line. Do not rewrite old records.

## Index

| #    | Title                                                                                     | Status   |
| ---- | ----------------------------------------------------------------------------------------- | -------- |
| 0001 | [Use XcodeGen with a gitignored `Local.xcconfig`](0001-xcodegen-local-xcconfig.md)        | Accepted |
| 0002 | [Swift Testing as the test framework](0002-swift-testing.md)                              | Accepted |
| 0003 | [Red/Green TDD is the default workflow](0003-tdd-working-style.md)                        | Accepted |
| 0004 | [Data Protection Keychain for secret storage](0004-data-protection-keychain.md)           | Accepted |
| 0005 | [MenuBar popover + separate Window scene, Dock icon hidden](0005-menu-bar-and-window.md)  | Accepted |
| 0006 | [Dependency-injected seams on `QuoteEngine`](0006-quote-engine-injection-seams.md)        | Accepted |
| 0007 | [SwiftData `@Query` reads + `@MainActor` store writes](0007-swiftdata-read-write-split.md) | Accepted |
| 0008 | [Poll Finnhub on a timer; no websocket](0008-polling-over-websocket.md)                   | Accepted |
