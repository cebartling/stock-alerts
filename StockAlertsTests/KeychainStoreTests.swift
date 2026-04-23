import Testing
import Foundation
@testable import StockAlerts

struct KeychainStoreTests {

    /// Each test gets a unique service name to avoid cross-test contamination
    /// and to leave no residue if a test crashes mid-run.
    private func makeStore() -> KeychainStore {
        KeychainStore(service: "com.pintailconsultingllc.StockAlertsTests.\(UUID().uuidString)")
    }

    @Test
    func read_onEmpty_returnsEmptyString() {
        let store = makeStore()
        defer { store.delete() }
        #expect(store.read() == "")
    }

    @Test
    func writeThenRead_roundTrips() {
        let store = makeStore()
        defer { store.delete() }
        store.write("abc-123")
        #expect(store.read() == "abc-123")
    }

    @Test
    func write_overwritesPreviousValue() {
        let store = makeStore()
        defer { store.delete() }
        store.write("first")
        store.write("second")
        #expect(store.read() == "second")
    }

    @Test
    func delete_clearsValue() {
        let store = makeStore()
        store.write("temp")
        store.delete()
        #expect(store.read() == "")
    }

    @Test
    func delete_onEmptyIsNoOp() {
        let store = makeStore()
        store.delete()
        #expect(store.read() == "")
    }

    @Test
    func write_emptyString_isStored() {
        let store = makeStore()
        defer { store.delete() }
        store.write("not empty")
        store.write("")
        #expect(store.read() == "")
    }
}
