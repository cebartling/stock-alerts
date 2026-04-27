import Testing
import Foundation
@testable import StockAlerts

struct QuoteTests {

    private func makeQuote(price: Double, prevClose: Double) -> Quote {
        Quote(
            symbol: "AAPL",
            price: price,
            previousClose: prevClose,
            open: price,
            high: price,
            low: price,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test
    func changeAbsolute_isPriceMinusPreviousClose_positive() {
        let q = makeQuote(price: 110, prevClose: 100)
        #expect(q.changeAbsolute == 10)
    }

    @Test
    func changeAbsolute_isPriceMinusPreviousClose_negative() {
        let q = makeQuote(price: 90, prevClose: 100)
        #expect(q.changeAbsolute == -10)
    }

    @Test
    func changeAbsolute_whenUnchanged_isZero() {
        let q = makeQuote(price: 100, prevClose: 100)
        #expect(q.changeAbsolute == 0)
    }

    @Test
    func changePercent_isPercentageChange_positive() {
        let q = makeQuote(price: 110, prevClose: 100)
        #expect(q.changePercent == 10)
    }

    @Test
    func changePercent_isPercentageChange_negative() {
        let q = makeQuote(price: 95, prevClose: 100)
        #expect(q.changePercent == -5)
    }

    @Test
    func changePercent_whenUnchanged_isZero() {
        let q = makeQuote(price: 100, prevClose: 100)
        #expect(q.changePercent == 0)
    }

    @Test
    func changePercent_handlesFractionalMoves() {
        let q = makeQuote(price: 101.5, prevClose: 100)
        #expect(abs(q.changePercent - 1.5) < 1e-9)
    }

    @Test
    func equality_matchesOnAllFields() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let a = Quote(symbol: "AAPL", price: 100, previousClose: 99, open: 99.5, high: 101, low: 98.5, timestamp: t)
        let b = Quote(symbol: "AAPL", price: 100, previousClose: 99, open: 99.5, high: 101, low: 98.5, timestamp: t)
        #expect(a == b)
    }

    @Test
    func equality_differsWhenAnyFieldDiffers() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let base = Quote(symbol: "AAPL", price: 100, previousClose: 99, open: 99.5, high: 101, low: 98.5, timestamp: t)
        #expect(base != Quote(symbol: "MSFT", price: 100, previousClose: 99, open: 99.5, high: 101, low: 98.5, timestamp: t))
        #expect(base != Quote(symbol: "AAPL", price: 101, previousClose: 99, open: 99.5, high: 101, low: 98.5, timestamp: t))
        #expect(base != Quote(symbol: "AAPL", price: 100, previousClose: 98, open: 99.5, high: 101, low: 98.5, timestamp: t))
        #expect(base != Quote(symbol: "AAPL", price: 100, previousClose: 99, open: 99.6, high: 101, low: 98.5, timestamp: t))
        #expect(base != Quote(symbol: "AAPL", price: 100, previousClose: 99, open: 99.5, high: 101.1, low: 98.5, timestamp: t))
        #expect(base != Quote(symbol: "AAPL", price: 100, previousClose: 99, open: 99.5, high: 101, low: 98.4, timestamp: t))
        #expect(base != Quote(symbol: "AAPL", price: 100, previousClose: 99, open: 99.5, high: 101, low: 98.5, timestamp: t.addingTimeInterval(1)))
    }
}
