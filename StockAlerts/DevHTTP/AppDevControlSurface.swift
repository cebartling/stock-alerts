#if DEBUG
import Foundation
import Domain

/// Binds the `DevControlSurface` port onto the live `QuoteEngineViewModel`, so
/// the dev HTTP routes drive the exact same seam the SwiftUI views use (every
/// mutation still goes through the view-model's `refresh()`).
@MainActor
final class AppDevControlSurface: DevControlSurface {
    private let viewModel: QuoteEngineViewModel

    init(viewModel: QuoteEngineViewModel) {
        self.viewModel = viewModel
    }

    func state() -> StateDTO {
        StateDTO(
            quotes: viewModel.quotes,
            lastError: Self.describe(viewModel.lastError),
            lastSuccessfulFetch: viewModel.lastSuccessfulFetch,
            clockTick: viewModel.clockTick
        )
    }

    func watchlist() -> [String] {
        viewModel.watchlist.map(\.symbol)
    }

    func addSymbol(_ symbol: String) {
        viewModel.addSymbol(symbol)
    }

    func removeSymbol(_ symbol: String) {
        viewModel.removeSymbol(symbol)
    }

    func alerts(symbol: String?) -> [AlertDTO] {
        let all = viewModel.alerts
        let filtered = symbol.map { sym in all.filter { $0.symbol == sym.uppercased() } } ?? all
        return filtered.map(AlertDTO.init)
    }

    func addAlert(symbol: String, condition: String, threshold: Double) -> AlertDTO? {
        guard let cond = PriceAlert.Condition(rawValue: condition) else { return nil }
        let alert = PriceAlert(symbol: symbol, condition: cond, threshold: threshold)
        viewModel.addAlert(alert)
        return AlertDTO(alert)
    }

    func removeAlert(id: UUID) {
        viewModel.removeAlert(id: id)
    }

    func resetAlert(id: UUID) {
        viewModel.resetAlert(id: id)
    }

    func tick() async {
        await viewModel.tick()
    }

    private static func describe(_ error: QuoteServiceError?) -> String? {
        guard let error else { return nil }
        switch error {
        case .rateLimited:            return "rateLimited"
        case .invalidSymbol(let s):   return "invalidSymbol(\(s))"
        case .network(let e):         return "network(\(e))"
        case .decoding(let e):        return "decoding(\(e))"
        }
    }
}

private extension AlertDTO {
    init(_ alert: PriceAlert) {
        self.init(
            id: alert.id,
            symbol: alert.symbol,
            condition: alert.condition.rawValue,
            threshold: alert.threshold,
            isEnabled: alert.isEnabled,
            isTriggered: alert.isTriggered
        )
    }
}
#endif
