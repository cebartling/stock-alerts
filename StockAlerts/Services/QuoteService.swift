import Foundation

enum QuoteServiceError: Error {
    case rateLimited
    case invalidSymbol(String)
    case network(Error)
    case decoding(Error)
}

protocol QuoteService: Sendable {
    func fetchQuote(symbol: String) async throws -> Quote
    func fetchQuotes(symbols: [String]) async throws -> [Quote]
}
