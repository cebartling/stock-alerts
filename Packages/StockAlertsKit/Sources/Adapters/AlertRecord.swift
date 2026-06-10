import Foundation
import SwiftData
import Domain

/// SwiftData persistence record for a price alert. This is infrastructure: the
/// domain works in `PriceAlert` value types; this `@Model` exists only to store
/// them. Map across the boundary with `init(_:)` and `asDomain`.
@Model
public final class AlertRecord {
    public var id: UUID
    public var symbol: String
    public var condition: PriceAlert.Condition
    public var threshold: Double
    public var isEnabled: Bool
    public var isTriggered: Bool
    public var createdAt: Date
    public var triggeredAt: Date?

    public init(_ alert: PriceAlert) {
        self.id = alert.id
        self.symbol = alert.symbol
        self.condition = alert.condition
        self.threshold = alert.threshold
        self.isEnabled = alert.isEnabled
        self.isTriggered = alert.isTriggered
        self.createdAt = alert.createdAt
        self.triggeredAt = alert.triggeredAt
    }

    public var asDomain: PriceAlert {
        PriceAlert(
            id: id,
            symbol: symbol,
            condition: condition,
            threshold: threshold,
            isEnabled: isEnabled,
            isTriggered: isTriggered,
            createdAt: createdAt,
            triggeredAt: triggeredAt
        )
    }
}
