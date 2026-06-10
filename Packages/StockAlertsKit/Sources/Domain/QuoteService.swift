import Foundation

public enum QuoteServiceError: Error {
    case rateLimited
    case invalidSymbol(String)
    case network(Error)
    case decoding(Error)
}

// Driven port: the application core depends on this abstraction; the Finnhub
// adapter (in the Adapters module / app target) conforms to it.
public protocol QuoteService: Sendable {
    func fetchQuote(symbol: String) async throws -> Quote
    func fetchQuotes(symbols: [String]) async throws -> [Quote]
}
