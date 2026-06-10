import Testing
import Foundation
import SwiftData
import Domain
import Adapters

@MainActor
struct SwiftDataWatchlistRepositoryTests {

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

    private func makeRepository() -> SwiftDataWatchlistRepository {
        SwiftDataWatchlistRepository(context: context)
    }

    @Test
    func newRepository_isEmpty() {
        let repo = makeRepository()
        #expect(repo.symbols.isEmpty)
    }

    @Test
    func add_appendsSymbol() {
        let repo = makeRepository()
        repo.add("AAPL")
        #expect(repo.symbols == ["AAPL"])
    }

    @Test
    func add_uppercasesSymbol() {
        let repo = makeRepository()
        repo.add("aapl")
        #expect(repo.symbols == ["AAPL"])
    }

    @Test
    func add_duplicateIsNoOp() {
        let repo = makeRepository()
        repo.add("AAPL")
        repo.add("aapl")
        #expect(repo.symbols == ["AAPL"])
    }

    @Test
    func add_preservesInsertionOrder() {
        let repo = makeRepository()
        repo.add("AAPL")
        repo.add("MSFT")
        repo.add("GOOG")
        #expect(repo.symbols == ["AAPL", "MSFT", "GOOG"])
    }

    @Test
    func remove_deletesSymbol() {
        let repo = makeRepository()
        repo.add("AAPL")
        repo.add("MSFT")
        repo.remove("AAPL")
        #expect(repo.symbols == ["MSFT"])
    }

    @Test
    func remove_unknownSymbolIsNoOp() {
        let repo = makeRepository()
        repo.add("AAPL")
        repo.remove("ZZZZ")
        #expect(repo.symbols == ["AAPL"])
    }

    @Test
    func reorder_movesSymbol() {
        let repo = makeRepository()
        repo.add("A")
        repo.add("B")
        repo.add("C")
        repo.add("D")
        // Move "A" (index 0) to offset 3 -> expected: B, C, A, D
        repo.reorder(from: IndexSet(integer: 0), to: 3)
        #expect(repo.symbols == ["B", "C", "A", "D"])
    }

    @Test
    func symbolsPersistAcrossRepositoryInstances() {
        let first = makeRepository()
        first.add("AAPL")
        first.add("MSFT")

        let second = makeRepository()
        #expect(second.symbols == ["AAPL", "MSFT"])
    }

    @Test
    func reorder_movesLastToFront() {
        let repo = makeRepository()
        repo.add("A")
        repo.add("B")
        repo.add("C")
        // Move C (index 2) to offset 0 -> expected: C, A, B
        repo.reorder(from: IndexSet(integer: 2), to: 0)
        #expect(repo.symbols == ["C", "A", "B"])
    }

    @Test
    func reorder_moveToSameOffset_isNoOp() {
        let repo = makeRepository()
        repo.add("A")
        repo.add("B")
        repo.add("C")
        // Moving A to offset 0 (its current position) is a no-op.
        repo.reorder(from: IndexSet(integer: 0), to: 0)
        #expect(repo.symbols == ["A", "B", "C"])
    }

    @Test
    func reorder_onSingleItemList_remainsStable() {
        let repo = makeRepository()
        repo.add("ONLY")
        repo.reorder(from: IndexSet(integer: 0), to: 1)
        #expect(repo.symbols == ["ONLY"])
    }

    @Test
    func remove_preservesOrderOfRemainingItems() {
        let repo = makeRepository()
        repo.add("A")
        repo.add("B")
        repo.add("C")
        repo.add("D")
        repo.remove("B")
        #expect(repo.symbols == ["A", "C", "D"])
    }

    @Test
    func addAfterRemove_placesNewSymbolAtEnd() {
        let repo = makeRepository()
        repo.add("A")
        repo.add("B")
        repo.remove("A")
        repo.add("C")
        #expect(repo.symbols == ["B", "C"])
    }
}
