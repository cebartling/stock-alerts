import Testing
import Foundation
import SwiftData
import Adapters

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
                for: SymbolRecord.self, AlertRecord.self,
                configurations: firstConfig
            )
            let firstRepo = SwiftDataWatchlistRepository(context: firstContainer.mainContext)
            firstRepo.add("AAPL")
            firstRepo.add("MSFT")
            #expect(firstRepo.symbols == ["AAPL", "MSFT"])
        }

        let secondConfig = ModelConfiguration(url: storeURL)
        let secondContainer = try ModelContainer(
            for: SymbolRecord.self, AlertRecord.self,
            configurations: secondConfig
        )
        let secondRepo = SwiftDataWatchlistRepository(context: secondContainer.mainContext)
        #expect(secondRepo.symbols == ["AAPL", "MSFT"])
    }

    private static func removeStoreArtifacts(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let path = url.path + suffix
            try? fm.removeItem(atPath: path)
        }
    }
}
