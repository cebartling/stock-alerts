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

    @Test
    func differentServices_doNotInterfere() {
        let tag = UUID().uuidString
        let a = KeychainStore(service: "com.pintailconsultingllc.StockAlertsTests.A.\(tag)")
        let b = KeychainStore(service: "com.pintailconsultingllc.StockAlertsTests.B.\(tag)")
        defer { a.delete(); b.delete() }

        a.write("alpha")
        b.write("beta")

        #expect(a.read() == "alpha")
        #expect(b.read() == "beta")
    }

    @Test
    func differentAccountsUnderSameService_doNotInterfere() {
        let service = "com.pintailconsultingllc.StockAlertsTests.acct.\(UUID().uuidString)"
        let first = KeychainStore(service: service, account: "first")
        let second = KeychainStore(service: service, account: "second")
        defer { first.delete(); second.delete() }

        first.write("A")
        second.write("B")

        #expect(first.read() == "A")
        #expect(second.read() == "B")
    }

    @Test
    func unicodeValues_roundTrip() {
        let store = makeStore()
        defer { store.delete() }
        let value = "key-🔑-日本語-\u{1F4A9}"
        store.write(value)
        #expect(store.read() == value)
    }

    @Test
    func longValue_roundTrips() {
        let store = makeStore()
        defer { store.delete() }
        let value = String(repeating: "x", count: 4096)
        store.write(value)
        #expect(store.read() == value)
    }

    @Test
    func writes_doNotPolluteLoginKeychainFile() throws {
        let store = makeStore()
        defer { store.delete() }
        store.write("secret-payload")

        // Shell out to /usr/bin/security, which operates on on-disk keychain
        // files directly and therefore can tell DPK items apart from
        // login.keychain-db items (the entitled in-process SecItem* API
        // unifies the two). find-generic-password exits non-zero if not found.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = [
            "find-generic-password",
            "-s", store.service,
            NSString(string: "~/Library/Keychains/login.keychain-db").expandingTildeInPath,
        ]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        task.waitUntilExit()

        #expect(
            task.terminationStatus != 0,
            "Item with service \(store.service) must NOT be in login.keychain-db; security exit=\(task.terminationStatus)"
        )
    }

    @Test
    func deleteDoesNotAffectOtherServices() {
        let tag = UUID().uuidString
        let keep = KeychainStore(service: "com.pintailconsultingllc.StockAlertsTests.keep.\(tag)")
        let drop = KeychainStore(service: "com.pintailconsultingllc.StockAlertsTests.drop.\(tag)")
        defer { keep.delete(); drop.delete() }

        keep.write("kept")
        drop.write("dropped")
        drop.delete()

        #expect(keep.read() == "kept")
        #expect(drop.read() == "")
    }
}
