import Foundation

public struct Quote: Codable, Equatable, Sendable {
    public let symbol: String
    public let price: Double
    public let previousClose: Double
    public let open: Double
    public let high: Double
    public let low: Double
    public let timestamp: Date

    public init(
        symbol: String,
        price: Double,
        previousClose: Double,
        open: Double,
        high: Double,
        low: Double,
        timestamp: Date
    ) {
        self.symbol = symbol
        self.price = price
        self.previousClose = previousClose
        self.open = open
        self.high = high
        self.low = low
        self.timestamp = timestamp
    }

    public var changeAbsolute: Double { price - previousClose }
    public var changePercent: Double { (changeAbsolute / previousClose) * 100 }
}
