import Testing
import Foundation
import SwiftData
@testable import StockAlerts

@MainActor
struct WatchlistStorePersistenceTests {

    @Test
    func symbolsPersist_acrossContainerInstances_onDisk() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WatchlistPersistence-\(UUID().uuidString).store")
        defer { Self.removeStoreArtifacts(at: storeURL) }

        try autoreleasepool {
            let firstConfig = ModelConfiguration(url: storeURL)
            let firstContainer = try ModelContainer(
                for: WatchedSymbol.self, PriceAlert.self,
                configurations: firstConfig
            )
            let firstStore = WatchlistStore(context: firstContainer.mainContext)
            firstStore.add("AAPL")
            firstStore.add("MSFT")
            #expect(firstStore.symbols == ["AAPL", "MSFT"])
        }

        let secondConfig = ModelConfiguration(url: storeURL)
        let secondContainer = try ModelContainer(
            for: WatchedSymbol.self, PriceAlert.self,
            configurations: secondConfig
        )
        let secondStore = WatchlistStore(context: secondContainer.mainContext)
        #expect(secondStore.symbols == ["AAPL", "MSFT"])
    }

    private static func removeStoreArtifacts(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let path = url.path + suffix
            try? fm.removeItem(atPath: path)
        }
    }
}
