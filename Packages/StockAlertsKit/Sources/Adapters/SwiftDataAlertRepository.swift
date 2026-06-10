import Foundation
import SwiftData
import Domain

/// SwiftData-backed adapter conforming to the `AlertRepository` port. Stores
/// `AlertRecord`s and maps them to/from the domain's `PriceAlert` value type.
@MainActor
public final class SwiftDataAlertRepository: AlertRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func all() -> [PriceAlert] {
        fetchAll().map(\.asDomain)
    }

    public func alerts(for symbol: String) -> [PriceAlert] {
        let normalized = symbol.uppercased()
        return fetchAll()
            .filter { $0.symbol == normalized }
            .map(\.asDomain)
    }

    public func add(_ alert: PriceAlert) {
        context.insert(AlertRecord(alert))
        try? context.save()
    }

    public func remove(id: UUID) {
        guard let record = record(id: id) else { return }
        context.delete(record)
        try? context.save()
    }

    public func markTriggered(id: UUID) {
        guard let record = record(id: id) else { return }
        record.isTriggered = true
        record.triggeredAt = .now
        try? context.save()
    }

    public func reset(id: UUID) {
        guard let record = record(id: id) else { return }
        record.isTriggered = false
        record.triggeredAt = nil
        try? context.save()
    }

    private func fetchAll() -> [AlertRecord] {
        (try? context.fetch(FetchDescriptor<AlertRecord>())) ?? []
    }

    private func record(id: UUID) -> AlertRecord? {
        fetchAll().first { $0.id == id }
    }
}
