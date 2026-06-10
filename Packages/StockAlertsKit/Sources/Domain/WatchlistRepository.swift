import Foundation

/// Driven port for watchlist persistence. The application core depends on this
/// abstraction; a SwiftData-backed adapter (in the Adapters module) conforms.
@MainActor
public protocol WatchlistRepository {
    func all() -> [WatchedSymbol]
    func add(_ symbol: String)
    func remove(_ symbol: String)
    func reorder(from source: IndexSet, to destination: Int)
}

public extension WatchlistRepository {
    /// Ordered ticker symbols — the projection the polling engine needs.
    var symbols: [String] { all().map(\.symbol) }
}
