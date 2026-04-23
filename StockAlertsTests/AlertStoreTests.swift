import Testing
import Foundation
import SwiftData
@testable import StockAlerts

@MainActor
struct AlertStoreTests {
    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        let pair = try TestHelpers.makeInMemoryContainer()
        self.container = pair.container
        self.context = pair.context
    }

    @Test
    func alertsForSymbol_isEmptyInitially() {
        let store = AlertStore(context: context)
        #expect(store.alerts(for: "AAPL").isEmpty)
    }

    @Test
    func add_persistsAlert() {
        let store = AlertStore(context: context)
        store.add(PriceAlert(symbol: "AAPL", condition: .above, threshold: 200))
        #expect(store.alerts(for: "AAPL").count == 1)
    }

    @Test
    func alertsForSymbol_filtersBySymbol() {
        let store = AlertStore(context: context)
        store.add(PriceAlert(symbol: "AAPL", condition: .above, threshold: 200))
        store.add(PriceAlert(symbol: "MSFT", condition: .below, threshold: 300))
        #expect(store.alerts(for: "AAPL").count == 1)
        #expect(store.alerts(for: "MSFT").count == 1)
        #expect(store.alerts(for: "AAPL").first?.symbol == "AAPL")
    }

    @Test
    func alertsForSymbol_isCaseInsensitive() {
        let store = AlertStore(context: context)
        store.add(PriceAlert(symbol: "AAPL", condition: .above, threshold: 200))
        #expect(store.alerts(for: "aapl").count == 1)
    }

    @Test
    func remove_deletesAlert() {
        let store = AlertStore(context: context)
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 200)
        store.add(alert)
        store.remove(alert)
        #expect(store.alerts(for: "AAPL").isEmpty)
    }

    @Test
    func markTriggered_setsFlagsAndPersists() throws {
        let store = AlertStore(context: context)
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 200)
        store.add(alert)

        let before = Date()
        store.markTriggered(alert)
        let after = Date()

        #expect(alert.isTriggered == true)
        let triggeredAt = try #require(alert.triggeredAt)
        #expect(triggeredAt >= before)
        #expect(triggeredAt <= after)

        // Verify the change survived a save round-trip by refetching.
        let refetched = store.alerts(for: "AAPL").first
        #expect(refetched?.isTriggered == true)
    }

    @Test
    func reset_clearsTriggeredState() {
        let store = AlertStore(context: context)
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 200)
        store.add(alert)
        store.markTriggered(alert)
        store.reset(alert)

        #expect(alert.isTriggered == false)
        #expect(alert.triggeredAt == nil)
    }

    @Test
    func alertsForSymbol_unmatchedSymbol_returnsEmpty() {
        let store = AlertStore(context: context)
        store.add(PriceAlert(symbol: "AAPL", condition: .above, threshold: 1))
        #expect(store.alerts(for: "ZZZ").isEmpty)
    }

    @Test
    func multipleAlerts_onSameSymbol_allReturned() {
        let store = AlertStore(context: context)
        store.add(PriceAlert(symbol: "AAPL", condition: .above, threshold: 100))
        store.add(PriceAlert(symbol: "AAPL", condition: .below, threshold: 50))
        store.add(PriceAlert(symbol: "AAPL", condition: .percentChangeUp, threshold: 5))

        #expect(store.alerts(for: "AAPL").count == 3)
    }

    @Test
    func reset_onNeverTriggered_leavesStateFalse() {
        let store = AlertStore(context: context)
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 1)
        store.add(alert)
        store.reset(alert)

        #expect(alert.isTriggered == false)
        #expect(alert.triggeredAt == nil)
    }

    @Test
    func markTriggered_thenReset_thenMarkTriggered_refires() throws {
        let store = AlertStore(context: context)
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 1)
        store.add(alert)

        store.markTriggered(alert)
        #expect(alert.isTriggered == true)

        store.reset(alert)
        #expect(alert.isTriggered == false)
        #expect(alert.triggeredAt == nil)

        store.markTriggered(alert)
        #expect(alert.isTriggered == true)
        let triggeredAt = try #require(alert.triggeredAt)
        #expect(triggeredAt.timeIntervalSinceNow > -5)
    }
}
