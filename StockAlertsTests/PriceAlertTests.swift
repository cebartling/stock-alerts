import Testing
import Foundation
@testable import StockAlerts

struct PriceAlertTests {

    private func makeQuote(
        symbol: String = "AAPL",
        price: Double,
        previousClose: Double = 100.0
    ) -> Quote {
        Quote(
            symbol: symbol,
            price: price,
            previousClose: previousClose,
            open: price,
            high: price,
            low: price,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    // MARK: - above

    @Test
    func above_triggersWhenPriceAtThreshold() {
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 150)
        #expect(alert.evaluate(against: makeQuote(price: 150)) == true)
    }

    @Test
    func above_triggersWhenPriceAboveThreshold() {
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 150)
        #expect(alert.evaluate(against: makeQuote(price: 151)) == true)
    }

    @Test
    func above_doesNotTriggerWhenPriceBelowThreshold() {
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 150)
        #expect(alert.evaluate(against: makeQuote(price: 149.99)) == false)
    }

    // MARK: - below

    @Test
    func below_triggersWhenPriceAtThreshold() {
        let alert = PriceAlert(symbol: "AAPL", condition: .below, threshold: 100)
        #expect(alert.evaluate(against: makeQuote(price: 100)) == true)
    }

    @Test
    func below_triggersWhenPriceBelowThreshold() {
        let alert = PriceAlert(symbol: "AAPL", condition: .below, threshold: 100)
        #expect(alert.evaluate(against: makeQuote(price: 99)) == true)
    }

    @Test
    func below_doesNotTriggerWhenPriceAboveThreshold() {
        let alert = PriceAlert(symbol: "AAPL", condition: .below, threshold: 100)
        #expect(alert.evaluate(against: makeQuote(price: 100.01)) == false)
    }

    // MARK: - percentChangeUp

    @Test
    func percentChangeUp_triggersAtThreshold() {
        // price 105 from prevClose 100 => +5.0%
        let alert = PriceAlert(symbol: "AAPL", condition: .percentChangeUp, threshold: 5)
        #expect(alert.evaluate(against: makeQuote(price: 105, previousClose: 100)) == true)
    }

    @Test
    func percentChangeUp_triggersAboveThreshold() {
        // price 110 from prevClose 100 => +10.0%
        let alert = PriceAlert(symbol: "AAPL", condition: .percentChangeUp, threshold: 5)
        #expect(alert.evaluate(against: makeQuote(price: 110, previousClose: 100)) == true)
    }

    @Test
    func percentChangeUp_doesNotTriggerBelowThreshold() {
        // price 104 from prevClose 100 => +4.0%
        let alert = PriceAlert(symbol: "AAPL", condition: .percentChangeUp, threshold: 5)
        #expect(alert.evaluate(against: makeQuote(price: 104, previousClose: 100)) == false)
    }

    // MARK: - percentChangeDown

    @Test
    func percentChangeDown_triggersAtThreshold() {
        // price 95 from prevClose 100 => -5.0%; threshold stored as +5, evaluate uses -|threshold|
        let alert = PriceAlert(symbol: "AAPL", condition: .percentChangeDown, threshold: 5)
        #expect(alert.evaluate(against: makeQuote(price: 95, previousClose: 100)) == true)
    }

    @Test
    func percentChangeDown_triggersBelowNegativeThreshold() {
        // price 90 from prevClose 100 => -10.0%
        let alert = PriceAlert(symbol: "AAPL", condition: .percentChangeDown, threshold: 5)
        #expect(alert.evaluate(against: makeQuote(price: 90, previousClose: 100)) == true)
    }

    @Test
    func percentChangeDown_doesNotTriggerWhenLessNegativeThanThreshold() {
        // price 96 from prevClose 100 => -4.0% ; threshold 5 means trigger at <= -5%
        let alert = PriceAlert(symbol: "AAPL", condition: .percentChangeDown, threshold: 5)
        #expect(alert.evaluate(against: makeQuote(price: 96, previousClose: 100)) == false)
    }

    @Test
    func percentChangeDown_usesAbsoluteValueOfThreshold() {
        // negative threshold still means "drop by 5%" (evaluate takes -abs(threshold))
        let alert = PriceAlert(symbol: "AAPL", condition: .percentChangeDown, threshold: -5)
        #expect(alert.evaluate(against: makeQuote(price: 95, previousClose: 100)) == true)
        #expect(alert.evaluate(against: makeQuote(price: 96, previousClose: 100)) == false)
    }

    // MARK: - gating

    @Test
    func disabledAlert_neverTriggers() {
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 1)
        alert.isEnabled = false
        #expect(alert.evaluate(against: makeQuote(price: 9999)) == false)
    }

    @Test
    func alreadyTriggeredAlert_doesNotRetrigger() {
        let alert = PriceAlert(symbol: "AAPL", condition: .above, threshold: 1)
        alert.isTriggered = true
        #expect(alert.evaluate(against: makeQuote(price: 9999)) == false)
    }

    // MARK: - symbol normalization (init behavior per SPEC)

    @Test
    func init_uppercasesSymbol() {
        let alert = PriceAlert(symbol: "aapl", condition: .above, threshold: 1)
        #expect(alert.symbol == "AAPL")
    }
}
