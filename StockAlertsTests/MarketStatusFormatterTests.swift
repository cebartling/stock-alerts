import Testing
@testable import StockAlerts

struct MarketStatusFormatterTests {

    @Test
    func text_whenOpen_returnsMarketOpen() {
        #expect(MarketStatusFormatter.text(isOpen: true) == "Market Open")
    }

    @Test
    func text_whenClosed_returnsMarketClosed() {
        #expect(MarketStatusFormatter.text(isOpen: false) == "Market Closed")
    }
}
