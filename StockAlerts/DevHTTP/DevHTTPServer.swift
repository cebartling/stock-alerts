#if DEBUG
import Foundation
import Network

/// Minimal `NWListener`-backed HTTP/1.1 server, bound to 127.0.0.1, Debug-only.
/// Parses requests off the main thread (on `queue`), then hops to `@MainActor`
/// to invoke the router (whose surface touches the `@MainActor` view-model).
/// Handles one request per connection (`Connection: close`); enough for `curl`.
///
/// `@unchecked Sendable`: `listener` is only touched by start()/stop() (called
/// from the main actor), the receive loop runs serially on `queue`, and the
/// surface is only invoked inside the `@MainActor` hop.
final class DevHTTPServer: @unchecked Sendable {
    private let surface: DevControlSurface
    private let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.pintailconsultingllc.StockAlerts.DevHTTP")

    init(surface: DevControlSurface, port: UInt16 = 8765) {
        self.surface = surface
        self.port = Self.resolvePort(default: port)
    }

    private static func resolvePort(default fallback: UInt16) -> UInt16 {
        if let raw = ProcessInfo.processInfo.environment["STOCKALERTS_DEV_PORT"], let p = UInt16(raw) {
            return p
        }
        return fallback
    }

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        let port = self.port
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:           NSLog("[DevHTTP] ready on http://127.0.0.1:%u", port)
            case .failed(let e):   NSLog("[DevHTTP] listener failed: %@", String(describing: e))
            case .cancelled:       NSLog("[DevHTTP] listener cancelled")
            default:               break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            // Loopback-only: reject any non-local peer (defense-in-depth for a dev port).
            guard Self.isLoopback(connection.endpoint) else { connection.cancel(); return }
            connection.start(queue: self.queue)
            self.receive(connection, buffer: Data())
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    private static func isLoopback(_ endpoint: NWEndpoint) -> Bool {
        guard case let .hostPort(host, _) = endpoint else { return false }
        switch host {
        case .ipv4(let address): return address.isLoopback
        case .ipv6(let address): return address.isLoopback
        case .name(let name, _): return name == "localhost"
        @unknown default:        return false
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }

            if let request = ParsedRequest(buffer) {
                Task { @MainActor in
                    let router = DevHTTPRouter(surface: self.surface)
                    let (status, json) = await router.route(method: request.method, path: request.path, body: request.body)
                    connection.send(content: Self.httpResponse(status: status, json: json),
                                    completion: .contentProcessed { _ in connection.cancel() })
                }
                return
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receive(connection, buffer: buffer)  // need more bytes
        }
    }

    private static func httpResponse(status: Int, json: Data) -> Data {
        let reason: String
        switch status {
        case 200: reason = "OK"
        case 400: reason = "Bad Request"
        case 404: reason = "Not Found"
        default:  reason = "Error"
        }
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        header += "Content-Type: application/json\r\n"
        header += "Content-Length: \(json.count)\r\n"
        header += "Connection: close\r\n\r\n"
        var out = Data(header.utf8)
        out.append(json)
        return out
    }
}

/// A fully-received HTTP request (request line + headers + Content-Length body).
/// `init?` returns nil while more bytes are still needed.
private struct ParsedRequest {
    let method: String
    let path: String
    let body: Data

    init?(_ data: Data) {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }  // headers incomplete
        let headerData = data.subdata(in: data.startIndex..<headerEnd.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = headerString.components(separatedBy: "\r\n")
        let requestLine = lines.first?.split(separator: " ") ?? []
        guard requestLine.count >= 2 else { return nil }

        var contentLength = 0
        for line in lines.dropFirst() {
            let kv = line.split(separator: ":", maxSplits: 1)
            if kv.count == 2, kv[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                contentLength = Int(kv[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }

        let bodyStart = headerEnd.upperBound
        let available = data.distance(from: bodyStart, to: data.endIndex)
        guard available >= contentLength else { return nil }  // body incomplete

        self.method = String(requestLine[0])
        self.path = String(requestLine[1])
        self.body = data.subdata(in: bodyStart..<data.index(bodyStart, offsetBy: contentLength))
    }
}
#endif
