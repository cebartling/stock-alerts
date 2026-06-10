#if DEBUG
import Foundation
import Domain

// Dev-only HTTP driving adapter. The whole DevHTTP/ directory is compiled out of
// Release builds (#if DEBUG), so the shipped binary never links Network or opens
// a port. It is a second driving adapter over the same QuoteEngine + repository
// ports the SwiftUI UI drives — see docs/architecture inspiration: fiti.

/// JSON shape for the engine state. Kept here (not on the Domain types) so the
/// dev wire format is decoupled from the domain model.
struct StateDTO: Codable, Equatable {
    var quotes: [String: Quote]
    var lastError: String?
    var lastSuccessfulFetch: Date?
    var clockTick: Date
}

/// JSON shape for a price alert.
struct AlertDTO: Codable, Equatable {
    var id: UUID
    var symbol: String
    var condition: String   // PriceAlert.Condition rawValue
    var threshold: Double
    var isEnabled: Bool
    var isTriggered: Bool
}

/// Port describing what the dev API can read and drive. `@MainActor` because the
/// only implementation touches the `@MainActor` view-model.
@MainActor
protocol DevControlSurface {
    func state() -> StateDTO
    func watchlist() -> [String]
    func addSymbol(_ symbol: String)
    func removeSymbol(_ symbol: String)
    func alerts(symbol: String?) -> [AlertDTO]
    func addAlert(symbol: String, condition: String, threshold: Double) -> AlertDTO?
    func removeAlert(id: UUID)
    func resetAlert(id: UUID)
    func tick() async
}
#endif
