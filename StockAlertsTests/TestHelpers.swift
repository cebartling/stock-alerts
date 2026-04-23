import Foundation
import SwiftData
@testable import StockAlerts

enum TestHelpers {
    /// Holds both the container and its context — the caller must retain the
    /// returned tuple for the duration of the test. `ModelContext` has only a
    /// weak reference to its container, so letting the container deallocate
    /// mid-test traps inside SwiftData.
    @MainActor
    static func makeInMemoryContainer() throws -> (container: ModelContainer, context: ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WatchedSymbol.self, PriceAlert.self,
            configurations: config
        )
        return (container, container.mainContext)
    }
}
