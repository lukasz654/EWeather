import SwiftUI
import WeatherDomain

struct HourlyForecastUpdateView: View {
    let state: ForecastUpdateState
    let displayedRange: HourlyForecastRange
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Wyświetlany zakres: \(displayedRange.rawValue) h")
                Spacer()
                ProgressView()
                    .controlSize(.small)
                    .opacity(state == .loading ? 1 : 0)
                    .accessibilityLabel("Aktualizowanie zakresu prognozy")
                    .accessibilityHidden(state != .loading)
            }
            switch state {
            case .idle, .loading:
                EmptyView()
            case .empty:
                Label("Brak nowej prognozy. Zachowano poprzednie dane.", systemImage: "cloud")
                retryButton
            case .failed(let failure):
                Label(message(for: failure), systemImage: failure == .offline ? "wifi.slash" : "exclamationmark.icloud")
                retryButton
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var retryButton: some View {
        Button("Spróbuj ponownie", action: retry)
            .buttonStyle(.borderless)
    }

    private func message(for failure: WeatherFailure) -> String {
        switch failure {
        case .offline: "Brak połączenia. Zachowano poprzednie dane."
        case .unavailable: "Nie udało się zaktualizować prognozy. Zachowano poprzednie dane."
        case .invalidData: "Nie można odczytać nowej prognozy. Zachowano poprzednie dane."
        }
    }
}
