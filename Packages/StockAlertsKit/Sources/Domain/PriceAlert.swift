import Foundation

public struct PriceAlert: Identifiable, Equatable, Sendable {
    public enum Condition: String, Codable, CaseIterable, Sendable {
        case above
        case below
        case percentChangeUp
        case percentChangeDown
    }

    public let id: UUID
    public var symbol: String
    public var condition: Condition
    public var threshold: Double
    public var isEnabled: Bool
    public var isTriggered: Bool
    public var createdAt: Date
    public var triggeredAt: Date?

    /// Designated initializer for a brand-new alert (fresh id, enabled, untriggered).
    public init(symbol: String, condition: Condition, threshold: Double) {
        self.id = UUID()
        self.symbol = symbol.uppercased()
        self.condition = condition
        self.threshold = threshold
        self.isEnabled = true
        self.isTriggered = false
        self.createdAt = .now
        self.triggeredAt = nil
    }

    /// Full initializer used to reconstruct an alert from persistence.
    public init(
        id: UUID,
        symbol: String,
        condition: Condition,
        threshold: Double,
        isEnabled: Bool,
        isTriggered: Bool,
        createdAt: Date,
        triggeredAt: Date?
    ) {
        self.id = id
        self.symbol = symbol
        self.condition = condition
        self.threshold = threshold
        self.isEnabled = isEnabled
        self.isTriggered = isTriggered
        self.createdAt = createdAt
        self.triggeredAt = triggeredAt
    }

    public func evaluate(against quote: Quote) -> Bool {
        guard isEnabled, !isTriggered else { return false }
        switch condition {
        case .above:             return quote.price >= threshold
        case .below:             return quote.price <= threshold
        case .percentChangeUp:   return quote.changePercent >= threshold
        case .percentChangeDown: return quote.changePercent <= -abs(threshold)
        }
    }
}
