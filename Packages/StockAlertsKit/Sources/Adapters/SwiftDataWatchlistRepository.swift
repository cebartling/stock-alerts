import Foundation
import SwiftData
import Domain

/// SwiftData-backed adapter conforming to the `WatchlistRepository` port. Stores
/// `SymbolRecord`s and maps them to the domain's `WatchedSymbol` value type.
@MainActor
public final class SwiftDataWatchlistRepository: WatchlistRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func all() -> [WatchedSymbol] {
        fetchAll().map(\.asDomain)
    }

    public func add(_ symbol: String) {
        let normalized = symbol.uppercased()
        let existing = fetchAll()
        guard !existing.contains(where: { $0.symbol == normalized }) else { return }
        let nextOrder = (existing.last?.sortOrder ?? -1) + 1
        context.insert(SymbolRecord(symbol: normalized, sortOrder: nextOrder))
        try? context.save()
    }

    public func remove(_ symbol: String) {
        let normalized = symbol.uppercased()
        let matches = fetchAll().filter { $0.symbol == normalized }
        for match in matches { context.delete(match) }
        try? context.save()
    }

    public func reorder(from source: IndexSet, to destination: Int) {
        var ordered = fetchAll()
        // Equivalent to SwiftUI's Array.move(fromOffsets:toOffset:), implemented
        // here so the persistence adapter need not depend on SwiftUI.
        let moving = source.sorted().map { ordered[$0] }
        for index in source.sorted(by: >) { ordered.remove(at: index) }
        let insertionIndex = destination - source.filter { $0 < destination }.count
        ordered.insert(contentsOf: moving, at: insertionIndex)
        for (index, item) in ordered.enumerated() {
            item.sortOrder = index
        }
        try? context.save()
    }

    private func fetchAll() -> [SymbolRecord] {
        let descriptor = FetchDescriptor<SymbolRecord>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
