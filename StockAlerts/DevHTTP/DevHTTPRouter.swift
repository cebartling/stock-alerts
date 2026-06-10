#if DEBUG
import Foundation

/// Pure request → response dispatch over a `DevControlSurface`. No Network
/// dependency, so it is fully unit-testable with a fake surface.
@MainActor
struct DevHTTPRouter {
    let surface: DevControlSurface

    private struct SymbolBody: Decodable { let symbol: String }
    private struct AlertBody: Decodable { let symbol: String; let condition: String; let threshold: Double }

    func route(method: String, path: String, body: Data) async -> (status: Int, json: Data) {
        let split = path.split(separator: "?", maxSplits: 1)
        let pathOnly = String(split.first ?? "")
        let query = split.count > 1 ? String(split[1]) : ""
        let seg = pathOnly.split(separator: "/").map(String.init)

        switch seg.first {
        case "state":     return routeState(method, seg)
        case "watchlist": return routeWatchlist(method, seg, body)
        case "alerts":    return routeAlerts(method, seg, query, body)
        case "tick":      return await routeTick(method, seg)
        default:          return notFound(method, pathOnly)
        }
    }

    private func routeState(_ method: String, _ seg: [String]) -> (Int, Data) {
        guard method == "GET", seg.count == 1 else { return notFound(method, "/" + seg.joined(separator: "/")) }
        return (200, json(surface.state()))
    }

    private func routeWatchlist(_ method: String, _ seg: [String], _ body: Data) -> (Int, Data) {
        switch (method, seg.count) {
        case ("GET", 1):
            return (200, json(surface.watchlist()))
        case ("POST", 1):
            guard let parsed = try? JSONDecoder().decode(SymbolBody.self, from: body) else {
                return (400, errorJSON("malformed body; expected {\"symbol\":\"…\"}"))
            }
            surface.addSymbol(parsed.symbol)
            return (200, json(surface.watchlist()))
        case ("DELETE", 2):
            surface.removeSymbol(seg[1])
            return (200, json(surface.watchlist()))
        default:
            return notFound(method, "/" + seg.joined(separator: "/"))
        }
    }

    private func routeAlerts(_ method: String, _ seg: [String], _ query: String, _ body: Data) -> (Int, Data) {
        switch (method, seg.count) {
        case ("GET", 1):
            return (200, json(surface.alerts(symbol: queryValue("symbol", in: query))))
        case ("POST", 1):
            return createAlert(body)
        case ("POST", 3) where seg[2] == "reset":
            return withAlertID(seg[1]) { surface.resetAlert(id: $0) }
        case ("DELETE", 2):
            return withAlertID(seg[1]) { surface.removeAlert(id: $0) }
        default:
            return notFound(method, "/" + seg.joined(separator: "/"))
        }
    }

    private func routeTick(_ method: String, _ seg: [String]) async -> (Int, Data) {
        guard method == "POST", seg.count == 1 else { return notFound(method, "/" + seg.joined(separator: "/")) }
        await surface.tick()
        return (200, json(surface.state()))
    }

    private func createAlert(_ body: Data) -> (Int, Data) {
        guard let parsed = try? JSONDecoder().decode(AlertBody.self, from: body) else {
            return (400, errorJSON("malformed body; expected {\"symbol\",\"condition\",\"threshold\"}"))
        }
        guard let dto = surface.addAlert(symbol: parsed.symbol, condition: parsed.condition, threshold: parsed.threshold) else {
            return (400, errorJSON("invalid condition '\(parsed.condition)'"))
        }
        return (200, json(dto))
    }

    private func withAlertID(_ raw: String, _ action: (UUID) -> Void) -> (Int, Data) {
        guard let id = UUID(uuidString: raw) else { return (400, errorJSON("invalid alert id")) }
        action(id)
        return (200, okJSON())
    }

    private func notFound(_ method: String, _ path: String) -> (Int, Data) {
        (404, errorJSON("no route for \(method) \(path)"))
    }

    // MARK: - encoding

    private func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    private func json<T: Encodable>(_ value: T) -> Data {
        (try? encoder().encode(value)) ?? Data("{}".utf8)
    }

    private func okJSON() -> Data { json(["ok": true]) }
    private func errorJSON(_ message: String) -> Data { json(["error": message]) }

    private func queryValue(_ name: String, in query: String) -> String? {
        for pair in query.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2, kv[0] == name {
                return String(kv[1]).removingPercentEncoding ?? String(kv[1])
            }
        }
        return nil
    }
}
#endif
