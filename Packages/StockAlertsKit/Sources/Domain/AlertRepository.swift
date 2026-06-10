import Foundation

/// Driven port for alert persistence. The application core depends on this
/// abstraction; a SwiftData-backed adapter (in the Adapters module) conforms.
@MainActor
public protocol AlertRepository {
    func all() -> [PriceAlert]
    func alerts(for symbol: String) -> [PriceAlert]
    func add(_ alert: PriceAlert)
    func remove(id: UUID)
    func markTriggered(id: UUID)
    func reset(id: UUID)
}
