# ADR-0007: SwiftData `@Query` reads + `@MainActor` store writes

- **Status**: Accepted
- **Date**: 2026-04-23

## Context

SwiftData offers two very different access patterns:

- `@Query` in SwiftUI views — reactive reads that refresh the view when the underlying `@Model` data changes.
- `ModelContext` mutations — imperative writes to the backing store.

We need both. Views must update when a quote price or an alert's `isTriggered` flips. The `QuoteEngine` and user actions (add symbol, add alert) need a call-site to write.

## Decision

- **Reads use `@Query` directly in views.** `MenuBarLabel`, `MenuBarPopoverView`, `MainWindowView`, and `SymbolDetailView` all declare `@Query(sort: \WatchedSymbol.sortOrder) private var symbols: [WatchedSymbol]` (and similar for `PriceAlert`) rather than reading through a store.
- **Writes go through `@MainActor` store wrappers.** `WatchlistStore` and `AlertStore` are plain `@MainActor` Swift classes that hold a `ModelContext` and expose semantic methods (`add`, `remove`, `reorder`, `markTriggered`, `reset`). The engine calls `alertStore.markTriggered(alert)` rather than mutating `alert.isTriggered = true` and remembering to save.
- **The `ModelContainer` is held at app-scope** as a `private let` on `StockAlertsApp`. Contexts handed to stores are the container's `mainContext`.

## Consequences

- The engine never touches `@Model` properties directly. Save sites are concentrated inside the stores and testable in isolation (`AlertStoreTests`, `WatchlistStoreTests`).
- Views stay thin and reactive. No `ObservableObject` wrapper layer over SwiftData — doing so was tried briefly during Phase 8 (`WatchlistStoreObject`) and discarded because `@Query` already delivers the same reactivity natively.
- Tests use `TestHelpers.makeInMemoryContainer()` which returns **both** the container and its context — the context holds only a weak reference to its container, and letting the container deallocate mid-test traps inside SwiftData with `EXC_BREAKPOINT` and a "type metadata for `<ModelType>`" frame. Each test suite stores both as `let` properties in its `init()`.

## Alternatives considered

- **ObservableObject wrappers over stores, with `@Published` arrays**: adds an indirection layer without reactivity benefits over `@Query`, and forces manual `objectWillChange.send()` around every mutation.
- **Bypass stores, let views call `context.insert`/`.delete` directly**: scatters save sites, complicates validation (e.g., symbol uppercasing, duplicate rejection), and makes engine-side mutations untestable.
