#if DEBUG
import Testing
import Foundation
import Domain
@testable import StockAlerts

@MainActor
struct DevHTTPRouterTests {

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private func quote(_ symbol: String, _ price: Double) -> Quote {
        Quote(symbol: symbol, price: price, previousClose: 100, open: price, high: price, low: price,
              timestamp: Date(timeIntervalSince1970: 1_700_000_000))
    }

    // MARK: - state

    @Test
    func getState_returns200_withEncodedState() async throws {
        let fake = FakeDevControlSurface()
        fake.stateDTO = StateDTO(
            quotes: ["AAPL": quote("AAPL", 150)],
            lastError: "rateLimited",
            lastSuccessfulFetch: Date(timeIntervalSince1970: 1_700_000_000),
            clockTick: Date(timeIntervalSince1970: 1_700_000_060)
        )
        let router = DevHTTPRouter(surface: fake)

        let (status, json) = await router.route(method: "GET", path: "/state", body: Data())

        #expect(status == 200)
        let dto = try decoder().decode(StateDTO.self, from: json)
        #expect(dto.quotes["AAPL"]?.price == 150)
        #expect(dto.lastError == "rateLimited")
    }

    // MARK: - watchlist

    @Test
    func getWatchlist_returnsSymbols() async throws {
        let fake = FakeDevControlSurface()
        fake.watchlistSymbols = ["AAPL", "MSFT"]
        let router = DevHTTPRouter(surface: fake)

        let (status, json) = await router.route(method: "GET", path: "/watchlist", body: Data())

        #expect(status == 200)
        #expect(try decoder().decode([String].self, from: json) == ["AAPL", "MSFT"])
    }

    @Test
    func postWatchlist_addsSymbol_andReturnsUpdatedList() async throws {
        let fake = FakeDevControlSurface()
        let router = DevHTTPRouter(surface: fake)

        let body = Data(#"{"symbol":"msft"}"#.utf8)
        let (status, json) = await router.route(method: "POST", path: "/watchlist", body: body)

        #expect(status == 200)
        #expect(fake.added == ["msft"])
        #expect(try decoder().decode([String].self, from: json) == ["MSFT"])
    }

    @Test
    func postWatchlist_malformedBody_returns400() async {
        let fake = FakeDevControlSurface()
        let router = DevHTTPRouter(surface: fake)

        let (status, _) = await router.route(method: "POST", path: "/watchlist", body: Data("not json".utf8))

        #expect(status == 400)
        #expect(fake.added.isEmpty)
    }

    @Test
    func deleteWatchlistSymbol_removes() async {
        let fake = FakeDevControlSurface()
        fake.watchlistSymbols = ["AAPL"]
        let router = DevHTTPRouter(surface: fake)

        let (status, _) = await router.route(method: "DELETE", path: "/watchlist/AAPL", body: Data())

        #expect(status == 200)
        #expect(fake.removed == ["AAPL"])
    }

    // MARK: - alerts

    @Test
    func getAlerts_filtersBySymbolQuery() async throws {
        let fake = FakeDevControlSurface()
        fake.alertList = [
            AlertDTO(id: UUID(), symbol: "AAPL", condition: "above", threshold: 150, isEnabled: true, isTriggered: false),
            AlertDTO(id: UUID(), symbol: "MSFT", condition: "below", threshold: 50, isEnabled: true, isTriggered: false),
        ]
        let router = DevHTTPRouter(surface: fake)

        let (status, json) = await router.route(method: "GET", path: "/alerts?symbol=AAPL", body: Data())

        #expect(status == 200)
        let dtos = try decoder().decode([AlertDTO].self, from: json)
        #expect(dtos.count == 1)
        #expect(dtos.first?.symbol == "AAPL")
    }

    @Test
    func postAlert_createsAlert_andReturnsIt() async throws {
        let fake = FakeDevControlSurface()
        let router = DevHTTPRouter(surface: fake)

        let body = Data(#"{"symbol":"AAPL","condition":"above","threshold":150}"#.utf8)
        let (status, json) = await router.route(method: "POST", path: "/alerts", body: body)

        #expect(status == 200)
        #expect(fake.addedAlerts.count == 1)
        let dto = try decoder().decode(AlertDTO.self, from: json)
        #expect(dto.symbol == "AAPL")
        #expect(dto.condition == "above")
        #expect(dto.threshold == 150)
    }

    @Test
    func postAlert_invalidCondition_returns400() async {
        let fake = FakeDevControlSurface()
        let router = DevHTTPRouter(surface: fake)

        let body = Data(#"{"symbol":"AAPL","condition":"sideways","threshold":1}"#.utf8)
        let (status, _) = await router.route(method: "POST", path: "/alerts", body: body)

        #expect(status == 400)
    }

    @Test
    func postAlertReset_callsReset() async {
        let fake = FakeDevControlSurface()
        let id = UUID()
        let router = DevHTTPRouter(surface: fake)

        let (status, _) = await router.route(method: "POST", path: "/alerts/\(id.uuidString)/reset", body: Data())

        #expect(status == 200)
        #expect(fake.resetAlertIDs == [id])
    }

    @Test
    func deleteAlert_callsRemove() async {
        let fake = FakeDevControlSurface()
        let id = UUID()
        let router = DevHTTPRouter(surface: fake)

        let (status, _) = await router.route(method: "DELETE", path: "/alerts/\(id.uuidString)", body: Data())

        #expect(status == 200)
        #expect(fake.removedAlertIDs == [id])
    }

    // MARK: - tick

    @Test
    func postTick_invokesTickOnce() async {
        let fake = FakeDevControlSurface()
        let router = DevHTTPRouter(surface: fake)

        let (status, _) = await router.route(method: "POST", path: "/tick", body: Data())

        #expect(status == 200)
        #expect(fake.tickCount == 1)
    }

    // MARK: - unknown

    @Test
    func unknownRoute_returns404() async {
        let fake = FakeDevControlSurface()
        let router = DevHTTPRouter(surface: fake)

        let (status, _) = await router.route(method: "GET", path: "/nope", body: Data())

        #expect(status == 404)
    }
}

// MARK: - test double

@MainActor
final class FakeDevControlSurface: DevControlSurface {
    var stateDTO = StateDTO(quotes: [:], lastError: nil, lastSuccessfulFetch: nil,
                            clockTick: Date(timeIntervalSince1970: 0))
    var watchlistSymbols: [String] = []
    var alertList: [AlertDTO] = []

    private(set) var added: [String] = []
    private(set) var removed: [String] = []
    private(set) var addedAlerts: [(symbol: String, condition: String, threshold: Double)] = []
    private(set) var removedAlertIDs: [UUID] = []
    private(set) var resetAlertIDs: [UUID] = []
    private(set) var tickCount = 0

    func state() -> StateDTO { stateDTO }
    func watchlist() -> [String] { watchlistSymbols }

    func addSymbol(_ symbol: String) {
        added.append(symbol)
        watchlistSymbols.append(symbol.uppercased())
    }

    func removeSymbol(_ symbol: String) {
        removed.append(symbol)
        watchlistSymbols.removeAll { $0 == symbol.uppercased() }
    }

    func alerts(symbol: String?) -> [AlertDTO] {
        guard let symbol else { return alertList }
        return alertList.filter { $0.symbol == symbol.uppercased() }
    }

    func addAlert(symbol: String, condition: String, threshold: Double) -> AlertDTO? {
        guard ["above", "below", "percentChangeUp", "percentChangeDown"].contains(condition) else { return nil }
        let dto = AlertDTO(id: UUID(), symbol: symbol.uppercased(), condition: condition,
                           threshold: threshold, isEnabled: true, isTriggered: false)
        addedAlerts.append((symbol, condition, threshold))
        alertList.append(dto)
        return dto
    }

    func removeAlert(id: UUID) { removedAlertIDs.append(id) }
    func resetAlert(id: UUID) { resetAlertIDs.append(id) }
    func tick() async { tickCount += 1 }
}
#endif
