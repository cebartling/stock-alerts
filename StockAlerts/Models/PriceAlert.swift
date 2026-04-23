import Foundation
import SwiftData

@Model
final class PriceAlert {
    enum Condition: String, Codable, CaseIterable {
        case above
        case below
        case percentChangeUp
        case percentChangeDown
    }

    var id: UUID
    var symbol: String
    var condition: Condition
    var threshold: Double
    var isEnabled: Bool
    var isTriggered: Bool
    var createdAt: Date
    var triggeredAt: Date?

    init(symbol: String, condition: Condition, threshold: Double) {
        self.id = UUID()
        self.symbol = symbol.uppercased()
        self.condition = condition
        self.threshold = threshold
        self.isEnabled = true
        self.isTriggered = false
        self.createdAt = .now
    }

    func evaluate(against quote: Quote) -> Bool {
        guard isEnabled, !isTriggered else { return false }
        switch condition {
        case .above:             return quote.price >= threshold
        case .below:             return quote.price <= threshold
        case .percentChangeUp:   return quote.changePercent >= threshold
        case .percentChangeDown: return quote.changePercent <= -abs(threshold)
        }
    }
}
