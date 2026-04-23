import Foundation

actor FinnhubQuoteService: QuoteService {
    private let apiKey: String
    private let session: URLSession
    private let base = URL(string: "https://finnhub.io/api/v1")!

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func fetchQuote(symbol: String) async throws -> Quote {
        var components = URLComponents(
            url: base.appending(path: "quote"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            .init(name: "symbol", value: symbol),
            .init(name: "token", value: apiKey),
        ]

        let (data, response) = try await session.data(from: components.url!)

        guard let http = response as? HTTPURLResponse else {
            throw QuoteServiceError.network(URLError(.badServerResponse))
        }
        if http.statusCode == 429 { throw QuoteServiceError.rateLimited }

        struct Payload: Decodable {
            let c: Double   // current
            let pc: Double  // previous close
            let t: TimeInterval
        }

        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw QuoteServiceError.decoding(error)
        }

        guard payload.c > 0 else { throw QuoteServiceError.invalidSymbol(symbol) }

        return Quote(
            symbol: symbol,
            price: payload.c,
            previousClose: payload.pc,
            timestamp: Date(timeIntervalSince1970: payload.t)
        )
    }

    func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        try await withThrowingTaskGroup(of: Quote.self) { group in
            for symbol in symbols {
                group.addTask { try await self.fetchQuote(symbol: symbol) }
            }
            var quotes: [Quote] = []
            for try await quote in group { quotes.append(quote) }
            return quotes
        }
    }
}
