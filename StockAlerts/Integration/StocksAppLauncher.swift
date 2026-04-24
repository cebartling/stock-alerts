import Foundation
import AppKit

@MainActor
protocol URLOpening {
    func open(_ url: URL)
}

struct NSWorkspaceURLOpener: URLOpening {
    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

@MainActor
struct StocksAppLauncher {
    static let shared = StocksAppLauncher(opener: NSWorkspaceURLOpener())

    private let opener: URLOpening

    init(opener: URLOpening) {
        self.opener = opener
    }

    func open(symbol: String) {
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
