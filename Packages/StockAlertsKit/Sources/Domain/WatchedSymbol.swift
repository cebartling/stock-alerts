import Foundation

public struct WatchedSymbol: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var symbol: String
    public var sortOrder: Int
    public var addedAt: Date

    /// Designated initializer for a brand-new watchlist entry.
    public init(symbol: String, sortOrder: Int) {
        self.id = UUID()
        self.symbol = symbol.uppercased()
        self.sortOrder = sortOrder
        self.addedAt = .now
    }

    /// Full initializer used to reconstruct an entry from persistence.
    public init(id: UUID, symbol: String, sortOrder: Int, addedAt: Date) {
        self.id = id
        self.symbol = symbol
        self.sortOrder = sortOrder
        self.addedAt = addedAt
    }
}
