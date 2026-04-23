import Foundation
import SwiftData

@MainActor
final class AlertStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func alerts(for symbol: String) -> [PriceAlert] {
        let normalized = symbol.uppercased()
        let descriptor = FetchDescriptor<PriceAlert>()
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.symbol == normalized }
    }

    func add(_ alert: PriceAlert) {
        context.insert(alert)
        try? context.save()
    }

    func remove(_ alert: PriceAlert) {
        context.delete(alert)
        try? context.save()
    }

    func markTriggered(_ alert: PriceAlert) {
        alert.isTriggered = true
        alert.triggeredAt = .now
        try? context.save()
    }

    func reset(_ alert: PriceAlert) {
        alert.isTriggered = false
        alert.triggeredAt = nil
        try? context.save()
    }
}
