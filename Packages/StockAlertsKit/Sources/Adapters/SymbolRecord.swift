import Foundation
import SwiftData
import Domain

/// SwiftData persistence record for a watchlist entry. Infrastructure only; the
/// domain works in `WatchedSymbol` value types.
@Model
public final class SymbolRecord {
    public var id: UUID
    public var symbol: String
    public var sortOrder: Int
    public var addedAt: Date

    public init(symbol: String, sortOrder: Int) {
        self.id = UUID()
        self.symbol = symbol.uppercased()
        self.sortOrder = sortOrder
        self.addedAt = .now
    }

    public var asDomain: WatchedSymbol {
        WatchedSymbol(id: id, symbol: symbol, sortOrder: sortOrder, addedAt: addedAt)
    }
}
