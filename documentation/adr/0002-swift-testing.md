# ADR-0002: Swift Testing as the test framework

- **Status**: Accepted
- **Date**: 2026-04-23

## Context

The test target needed a framework at project creation. The deployment target is macOS 14, toolchain is Xcode 16+, and the test surface spans pure-logic types, SwiftData stores, concurrency-bearing actors, and URLSession-stubbed services.

## Decision

Use **Swift Testing** (`import Testing`, `@Test`, `#expect`, `#require`) for the `StockAlertsTests` target. All test files use the macro-based syntax.

## Consequences

- Test files read more naturally than XCTest equivalents: per-test suite instances (so `init()` is per-test setup), built-in `async` support for actor and async/await code, typed `#expect` / `#require` with good failure messages.
- No XCTest compatibility shim or intermingling. Every test in the suite uses `@Test`.
- Requires Xcode 16+ to build (already a hard requirement).
- First-party: no dependency added.

## Alternatives considered

- **XCTest**: mature and ubiquitous but carries ceremony (`XCTestCase` subclasses, `func testThing()` naming convention, weaker `XCTAssert*` diagnostics). No real advantage for a greenfield project on the current toolchain.
