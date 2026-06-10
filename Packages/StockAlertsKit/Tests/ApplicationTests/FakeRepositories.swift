import Foundation
import Domain

// In-memory fakes for the repository ports. They store domain value types
// directly — no SwiftData — so application-core tests stay fast and unsigned.

@MainActor
final class FakeAlertRepository: AlertRepository {
    private(set) var stored: [PriceAlert] = []

    func all() -> [PriceAlert] {
        stored
    }

    func alerts(for symbol: String) -> [PriceAlert] {
        let normalized = symbol.uppercased()
        return stored.filter { $0.symbol == normalized }
    }

    func add(_ alert: PriceAlert) {
        stored.append(alert)
    }

    func remove(id: UUID) {
        stored.removeAll { $0.id == id }
    }

    func markTriggered(id: UUID) {
        guard let index = stored.firstIndex(where: { $0.id == id }) else { return }
        stored[index].isTriggered = true
        stored[index].triggeredAt = .now
    }

    func reset(id: UUID) {
        guard let index = stored.firstIndex(where: { $0.id == id }) else { return }
        stored[index].isTriggered = false
        stored[index].triggeredAt = nil
    }
}

@MainActor
final class FakeWatchlistRepository: WatchlistRepository {
    private(set) var stored: [WatchedSymbol] = []

    func all() -> [WatchedSymbol] {
        stored.sorted { $0.sortOrder < $1.sortOrder }
    }

    func add(_ symbol: String) {
        let normalized = symbol.uppercased()
        guard !stored.contains(where: { $0.symbol == normalized }) else { return }
        stored.append(WatchedSymbol(symbol: normalized, sortOrder: stored.count))
    }

    func remove(_ symbol: String) {
        let normalized = symbol.uppercased()
        stored.removeAll { $0.symbol == normalized }
    }

    func reorder(from source: IndexSet, to destination: Int) {
        var ordered = all()
        let moving = source.sorted().map { ordered[$0] }
        for index in source.sorted(by: >) { ordered.remove(at: index) }
        let insertionIndex = destination - source.filter { $0 < destination }.count
        ordered.insert(contentsOf: moving, at: insertionIndex)
        stored = ordered.enumerated().map { index, item in
            WatchedSymbol(id: item.id, symbol: item.symbol, sortOrder: index, addedAt: item.addedAt)
        }
    }
}
