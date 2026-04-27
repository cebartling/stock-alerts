import Testing
import Foundation
@testable import StockAlerts

struct FinnhubQuoteServiceTests {

    private func http(_ url: URL, _ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
    }

    private func jsonData(_ payload: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: payload)
    }

    // MARK: - fetchQuote happy path

    @Test
    func fetchQuote_returnsParsedQuote() async throws {
        StubURLProtocol.requestHandler = { request in
            let data = try JSONSerialization.data(
                withJSONObject: [
                    "c": 123.45,
                    "pc": 120.00,
                    "o": 121.00,
                    "h": 124.00,
                    "l": 119.50,
                    "t": 1_700_000_000,
                ]
            )
            return (self.http(request.url!, 200), data)
        }
        defer { StubURLProtocol.reset() }

        let service = FinnhubQuoteService(apiKey: "secret", session: StubURLProtocol.makeSession())
        let quote = try await service.fetchQuote(symbol: "AAPL")

        #expect(quote.symbol == "AAPL")
        #expect(quote.price == 123.45)
        #expect(quote.previousClose == 120.00)
        #expect(quote.open == 121.00)
        #expect(quote.high == 124.00)
        #expect(quote.low == 119.50)
        #expect(quote.timestamp == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test
    func fetchQuote_requestContainsSymbolAndToken() async throws {
        nonisolated(unsafe) var capturedURL: URL?
        StubURLProtocol.requestHandler = { request in
            capturedURL = request.url
            let data = try JSONSerialization.data(
                withJSONObject: ["c": 1.0, "pc": 1.0, "o": 1.0, "h": 1.0, "l": 1.0, "t": 1_700_000_000]
            )
            return (self.http(request.url!, 200), data)
        }
        defer { StubURLProtocol.reset() }

        let service = FinnhubQuoteService(apiKey: "my-token", session: StubURLProtocol.makeSession())
        _ = try await service.fetchQuote(symbol: "AAPL")

        let url = try #require(capturedURL)
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(items["symbol"] == "AAPL")
        #expect(items["token"] == "my-token")
        #expect(url.path.contains("/quote"))
    }

    // MARK: - error cases

    @Test
    func fetchQuote_rateLimited_throwsRateLimited() async {
        StubURLProtocol.requestHandler = { request in
            (self.http(request.url!, 429), Data())
        }
        defer { StubURLProtocol.reset() }

        let service = FinnhubQuoteService(apiKey: "k", session: StubURLProtocol.makeSession())

        await #expect(throws: QuoteServiceError.self) {
            _ = try await service.fetchQuote(symbol: "AAPL")
        }
        do {
            _ = try await service.fetchQuote(symbol: "AAPL")
            Issue.record("Expected rateLimited error")
        } catch let error as QuoteServiceError {
            if case .rateLimited = error {
                // ok
            } else {
                Issue.record("Expected .rateLimited, got \(error)")
            }
        } catch {
            Issue.record("Expected QuoteServiceError, got \(error)")
        }
    }

    @Test
    func fetchQuote_zeroCurrentPrice_throwsInvalidSymbol() async {
        StubURLProtocol.requestHandler = { request in
            let data = try JSONSerialization.data(
                withJSONObject: ["c": 0, "pc": 0, "o": 0, "h": 0, "l": 0, "t": 0]
            )
            return (self.http(request.url!, 200), data)
        }
        defer { StubURLProtocol.reset() }

        let service = FinnhubQuoteService(apiKey: "k", session: StubURLProtocol.makeSession())

        do {
            _ = try await service.fetchQuote(symbol: "BOGUS")
            Issue.record("Expected invalidSymbol error")
        } catch let error as QuoteServiceError {
            if case .invalidSymbol(let sym) = error {
                #expect(sym == "BOGUS")
            } else {
                Issue.record("Expected .invalidSymbol, got \(error)")
            }
        } catch {
            Issue.record("Expected QuoteServiceError, got \(error)")
        }
    }

    @Test
    func fetchQuote_malformedJSON_throwsDecoding() async {
        StubURLProtocol.requestHandler = { request in
            (self.http(request.url!, 200), Data("not json".utf8))
        }
        defer { StubURLProtocol.reset() }

        let service = FinnhubQuoteService(apiKey: "k", session: StubURLProtocol.makeSession())

        do {
            _ = try await service.fetchQuote(symbol: "AAPL")
            Issue.record("Expected decoding error")
        } catch let error as QuoteServiceError {
            if case .decoding = error {
                // ok
            } else {
                Issue.record("Expected .decoding, got \(error)")
            }
        } catch {
            Issue.record("Expected QuoteServiceError, got \(error)")
        }
    }

    // MARK: - fetchQuotes (concurrent)

    @Test
    func fetchQuotes_returnsOnePerSymbol() async throws {
        StubURLProtocol.requestHandler = { request in
            let sym = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "symbol" })?.value ?? "?"
            let price: Double = sym == "AAPL" ? 100 : sym == "MSFT" ? 200 : 300
            let data = try JSONSerialization.data(
                withJSONObject: [
                    "c": price,
                    "pc": price - 1,
                    "o": price,
                    "h": price,
                    "l": price,
                    "t": 1_700_000_000,
                ]
            )
            return (self.http(request.url!, 200), data)
        }
        defer { StubURLProtocol.reset() }

        let service = FinnhubQuoteService(apiKey: "k", session: StubURLProtocol.makeSession())
        let quotes = try await service.fetchQuotes(symbols: ["AAPL", "MSFT", "GOOG"])

        #expect(quotes.count == 3)
        let bySymbol = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0.price) })
        #expect(bySymbol["AAPL"] == 100)
        #expect(bySymbol["MSFT"] == 200)
        #expect(bySymbol["GOOG"] == 300)
    }

    @Test
    func fetchQuotes_emptySymbols_returnsEmpty() async throws {
        // Handler is defensive but should never be called.
        nonisolated(unsafe) var callCount = 0
        StubURLProtocol.requestHandler = { request in
            callCount += 1
            let data = try JSONSerialization.data(
                withJSONObject: ["c": 1.0, "pc": 1.0, "o": 1.0, "h": 1.0, "l": 1.0, "t": 0]
            )
            return (self.http(request.url!, 200), data)
        }
        defer { StubURLProtocol.reset() }

        let service = FinnhubQuoteService(apiKey: "k", session: StubURLProtocol.makeSession())
        let quotes = try await service.fetchQuotes(symbols: [])
        #expect(quotes.isEmpty)
        #expect(callCount == 0)
    }

    @Test
    func fetchQuotes_partialFailure_throwsFirstError() async {
        // One symbol gets rate-limited. fetchQuotes uses withThrowingTaskGroup,
        // so any child throw makes the whole call throw.
        StubURLProtocol.requestHandler = { request in
            let sym = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "symbol" })?.value ?? "?"
            if sym == "BAD" {
                return (self.http(request.url!, 429), Data())
            }
            let data = try JSONSerialization.data(
                withJSONObject: [
                    "c": 100.0,
                    "pc": 99.0,
                    "o": 100.0,
                    "h": 100.0,
                    "l": 100.0,
                    "t": 1_700_000_000,
                ]
            )
            return (self.http(request.url!, 200), data)
        }
        defer { StubURLProtocol.reset() }

        let service = FinnhubQuoteService(apiKey: "k", session: StubURLProtocol.makeSession())

        do {
            _ = try await service.fetchQuotes(symbols: ["AAPL", "BAD"])
            Issue.record("Expected fetchQuotes to throw when one symbol fails")
        } catch let error as QuoteServiceError {
            if case .rateLimited = error {
                // ok — the BAD symbol's 429 bubbled up
            } else {
                Issue.record("Expected .rateLimited, got \(error)")
            }
        } catch {
            Issue.record("Expected QuoteServiceError, got \(error)")
        }
    }

    @Test
    func fetchQuote_requestHitsQuoteEndpoint() async throws {
        nonisolated(unsafe) var capturedURL: URL?
        StubURLProtocol.requestHandler = { request in
            capturedURL = request.url
            let data = try JSONSerialization.data(
                withJSONObject: ["c": 1.0, "pc": 1.0, "o": 1.0, "h": 1.0, "l": 1.0, "t": 0]
            )
            return (self.http(request.url!, 200), data)
        }
        defer { StubURLProtocol.reset() }

        let service = FinnhubQuoteService(apiKey: "k", session: StubURLProtocol.makeSession())
        _ = try await service.fetchQuote(symbol: "AAPL")

        let url = try #require(capturedURL)
        #expect(url.host == "finnhub.io")
        #expect(url.path == "/api/v1/quote")
        #expect(url.scheme == "https")
    }
}
