import Foundation

struct Quote: Codable, Equatable, Sendable {
    let symbol: String
    let price: Double
    let previousClose: Double
    let timestamp: Date

    var changeAbsolute: Double { price - previousClose }
    var changePercent: Double { (changeAbsolute / previousClose) * 100 }
}
