import Foundation
import AppKit

/// Port for opening URLs, so the launcher can be tested without hitting the
/// system Stocks app.
@MainActor
public protocol URLOpening {
    func open(_ url: URL)
}

public struct NSWorkspaceURLOpener: URLOpening {
    public init() {}
    public func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

/// Opens Apple's Stocks app at a given symbol via the `stocks://` URL scheme.
@MainActor
public struct StocksAppLauncher {
    public static let shared = StocksAppLauncher(opener: NSWorkspaceURLOpener())

    private let opener: URLOpening

    public init(opener: URLOpening) {
        self.opener = opener
    }

    public func open(symbol: String) {
        let normalized = symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalized.isEmpty else { return }

        var components = URLComponents()
        components.scheme = "stocks"
        components.host = ""
        components.queryItems = [URLQueryItem(name: "symbol", value: normalized)]
        guard let url = components.url else { return }

        opener.open(url)
    }
}
