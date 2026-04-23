import Foundation
import SwiftData

@MainActor
final class WatchlistStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    var symbols: [String] {
        fetchAll().map(\.symbol)
    }

    func add(_ symbol: String) {
        let normalized = symbol.uppercased()
        let existing = fetchAll()
        guard !existing.contains(where: { $0.symbol == normalized }) else { return }
        let nextOrder = (existing.last?.sortOrder ?? -1) + 1
        context.insert(WatchedSymbol(symbol: normalized, sortOrder: nextOrder))
        try? context.save()
    }

    func remove(_ symbol: String) {
        let normalized = symbol.uppercased()
        let matches = fetchAll().filter { $0.symbol == normalized }
        for match in matches { context.delete(match) }
        try? context.save()
    }

    func reorder(from source: IndexSet, to destination: Int) {
        var ordered = fetchAll()
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.sortOrder = index
        }
        try? context.save()
    }

    private func fetchAll() -> [WatchedSymbol] {
        let descriptor = FetchDescriptor<WatchedSymbol>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
