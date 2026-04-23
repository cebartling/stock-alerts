import Testing
import Foundation
import SwiftData
@testable import StockAlerts

@MainActor
struct WatchlistStoreTests {

    // Retain both container and context for the lifetime of each test by
    // storing them as struct properties. Swift Testing creates a fresh
    // instance per @Test, so the init runs once per test.
    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        let pair = try TestHelpers.makeInMemoryContainer()
        self.container = pair.container
        self.context = pair.context
    }

    @Test
    func newStore_isEmpty() {
        let store = WatchlistStore(context: context)
        #expect(store.symbols.isEmpty)
    }

    @Test
    func add_appendsSymbol() {
        let store = WatchlistStore(context: context)
        store.add("AAPL")
        #expect(store.symbols == ["AAPL"])
    }

    @Test
    func add_uppercasesSymbol() {
        let store = WatchlistStore(context: context)
        store.add("aapl")
        #expect(store.symbols == ["AAPL"])
    }

    @Test
    func add_duplicateIsNoOp() {
        let store = WatchlistStore(context: context)
        store.add("AAPL")
        store.add("aapl")
        #expect(store.symbols == ["AAPL"])
    }

    @Test
    func add_preservesInsertionOrder() {
        let store = WatchlistStore(context: context)
        store.add("AAPL")
        store.add("MSFT")
        store.add("GOOG")
        #expect(store.symbols == ["AAPL", "MSFT", "GOOG"])
    }

    @Test
    func remove_deletesSymbol() {
        let store = WatchlistStore(context: context)
        store.add("AAPL")
        store.add("MSFT")
        store.remove("AAPL")
        #expect(store.symbols == ["MSFT"])
    }

    @Test
    func remove_unknownSymbolIsNoOp() {
        let store = WatchlistStore(context: context)
        store.add("AAPL")
        store.remove("ZZZZ")
        #expect(store.symbols == ["AAPL"])
    }

    @Test
    func reorder_movesSymbol() {
        let store = WatchlistStore(context: context)
        store.add("A")
        store.add("B")
        store.add("C")
        store.add("D")
        // Move "A" (index 0) to offset 3 -> expected: B, C, A, D
        store.reorder(from: IndexSet(integer: 0), to: 3)
        #expect(store.symbols == ["B", "C", "A", "D"])
    }

    @Test
    func symbolsPersistAcrossStoreInstances() {
        let first = WatchlistStore(context: context)
        first.add("AAPL")
        first.add("MSFT")

        let second = WatchlistStore(context: context)
        #expect(second.symbols == ["AAPL", "MSFT"])
    }
}
