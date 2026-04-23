import Foundation
import SwiftData

@Model
final class WatchedSymbol {
    var id: UUID
    var symbol: String
    var sortOrder: Int
    var addedAt: Date

    init(symbol: String, sortOrder: Int) {
        self.id = UUID()
        self.symbol = symbol.uppercased()
        self.sortOrder = sortOrder
        self.addedAt = .now
    }
}
