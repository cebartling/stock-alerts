import Testing
import Foundation
@testable import StockAlerts

@MainActor
struct StocksAppLauncherTests {

    final class RecordingOpener: URLOpening, @unchecked Sendable {
        private(set) var openedURLs: [URL] = []
        func open(_ url: URL) {
            openedURLs.append(url)
        }
    }

    @Test
    func open_buildsStocksURL_withSymbolQueryItem() {
        let opener = RecordingOpener()
        let launcher = StocksAppLauncher(opener: opener)

        launcher.open(symbol: "AAPL")

        #expect(opener.openedURLs.count == 1)
        let components = URLComponents(url: opener.openedURLs[0], resolvingAgainstBaseURL: false)
        #expect(components?.scheme == "stocks")
        #expect(components?.queryItems?.first(where: { $0.name == "symbol" })?.value == "AAPL")
    }

    @Test
    func open_uppercasesSymbol() {
        let opener = RecordingOpener()
        let launcher = StocksAppLauncher(opener: opener)

        launcher.open(symbol: "aapl")

        let components = URLComponents(url: opener.openedURLs[0], resolvingAgainstBaseURL: false)
        #expect(components?.queryItems?.first(where: { $0.name == "symbol" })?.value == "AAPL")
    }

    @Test
    func open_trimsSurroundingWhitespace() {
        let opener = RecordingOpener()
        let launcher = StocksAppLauncher(opener: opener)

        launcher.open(symbol: "  msft  ")

        let components = URLComponents(url: opener.openedURLs[0], resolvingAgainstBaseURL: false)
        #expect(components?.queryItems?.first(where: { $0.name == "symbol" })?.value == "MSFT")
    }

    @Test
    func open_isNoOp_forEmptySymbol() {
        let opener = RecordingOpener()
        let launcher = StocksAppLauncher(opener: opener)

        launcher.open(symbol: "")
        launcher.open(symbol: "   ")

        #expect(opener.openedURLs.isEmpty)
    }
}
