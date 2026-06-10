import Testing
import Foundation
import SwiftData
import Domain
import Adapters

@MainActor
struct SwiftDataAlertRepositoryTests {
    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        let pair = try TestHelpers.makeInMemoryContainer()
        self.container = pair.container
        self.context = pair.context
    }

    private func makeRepository() -> SwiftDataAlertRepository {
        SwiftDataAlertRepository(context: context)
    }

    @Test
    func alertsForSymbol_isEmptyInitially() {
        let repo = makeRepository()
        #expect(repo.alerts(for: "AAPL").isEmpty)
    }

    @Test
    func add_persistsAlert() {
        let repo = makeRepository()
        repo.add(PriceAlert(symbol: "AAPL", condition: .above, threshold: 200))
        #expect(repo.alerts(for: "AAPL").count == 1)
    }

    @Test
    func alertsForSymbol_filtersBySymbol() {
        let repo = makeRepository()
        repo.add(PriceAlert(symbol: "AAPL", condition: .above, threshold: 200))
        repo.add(PriceAlert(symbol: "MSFT", condition: .below, threshold: 300))
        #expect(repo.alerts(for: "AAPL").count == 1)
        #expect(repo.alerts(for: "MSFT").count == 1)
        #expect(repo.alerts(for: "AAPL").first?.symbol == "AAPL")
    }

    @Test
    func alertsForSymbol_isCaseInsensitive() {
        let repo = makeRepository()
        repo.add(PriceAlert(symbol: "AAPL", condition: .above, threshold: 200))
        #expect(repo.alerts(for: "aapl").count == 1)
    }

    @Test
    func remove_deletesAlert() {
        let repo = makeRepository()
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 200)
        repo.add(alert)
        repo.remove(id: alert.id)
        #expect(repo.alerts(for: "AAPL").isEmpty)
    }

    @Test
    func markTriggered_setsFlagsAndPersists() throws {
        let repo = makeRepository()
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 200)
        repo.add(alert)

        let before = Date()
        repo.markTriggered(id: alert.id)
        let after = Date()

        // Repository returns value types, so re-fetch to observe the change.
        let refetched = try #require(repo.alerts(for: "AAPL").first)
        #expect(refetched.isTriggered == true)
        let triggeredAt = try #require(refetched.triggeredAt)
        #expect(triggeredAt >= before)
        #expect(triggeredAt <= after)
    }

    @Test
    func reset_clearsTriggeredState() throws {
        let repo = makeRepository()
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 200)
        repo.add(alert)
        repo.markTriggered(id: alert.id)
        repo.reset(id: alert.id)

        let refetched = try #require(repo.alerts(for: "AAPL").first)
        #expect(refetched.isTriggered == false)
        #expect(refetched.triggeredAt == nil)
    }

    @Test
    func alertsForSymbol_unmatchedSymbol_returnsEmpty() {
        let repo = makeRepository()
        repo.add(PriceAlert(symbol: "AAPL", condition: .above, threshold: 1))
        #expect(repo.alerts(for: "ZZZ").isEmpty)
    }

    @Test
    func multipleAlerts_onSameSymbol_allReturned() {
        let repo = makeRepository()
        repo.add(PriceAlert(symbol: "AAPL", condition: .above, threshold: 100))
        repo.add(PriceAlert(symbol: "AAPL", condition: .below, threshold: 50))
        repo.add(PriceAlert(symbol: "AAPL", condition: .percentChangeUp, threshold: 5))

        #expect(repo.alerts(for: "AAPL").count == 3)
    }

    @Test
    func reset_onNeverTriggered_leavesStateFalse() throws {
        let repo = makeRepository()
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 1)
        repo.add(alert)
        repo.reset(id: alert.id)

        let refetched = try #require(repo.alerts(for: "AAPL").first)
        #expect(refetched.isTriggered == false)
        #expect(refetched.triggeredAt == nil)
    }

    @Test
    func markTriggered_thenReset_thenMarkTriggered_refires() throws {
        let repo = makeRepository()
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 1)
        repo.add(alert)

        repo.markTriggered(id: alert.id)
        #expect(try #require(repo.alerts(for: "AAPL").first).isTriggered == true)

        repo.reset(id: alert.id)
        let afterReset = try #require(repo.alerts(for: "AAPL").first)
        #expect(afterReset.isTriggered == false)
        #expect(afterReset.triggeredAt == nil)

        repo.markTriggered(id: alert.id)
        let afterRefire = try #require(repo.alerts(for: "AAPL").first)
        #expect(afterRefire.isTriggered == true)
        let triggeredAt = try #require(afterRefire.triggeredAt)
        #expect(triggeredAt.timeIntervalSinceNow > -5)
    }
}
