import SwiftUI

struct DailyForecastSection: View {
    @Bindable var model: DailyForecastViewModel
    let retry: () -> Void

    var body: some View {
        Section {
            switch model.state {
            case .idle, .loading:
                LoadingView(message: "Pobieranie prognozy na 3 dni…")
            case .loaded(let days):
                ForEach(days) { DailyForecastRow(forecast: $0) }
            case .empty:
                StatusView(title: "Brak prognozy na 3 dni", systemImage: "calendar", message: "Prognoza dzienna dla tego miasta jest niedostępna.", retry: retry)
            case .failed(let failure):
                FailureView(failure: failure, retry: retry)
            }
        } header: {
            Text("Prognoza na 3 dni")
        } footer: {
            Text("Daty podano w czasie lokalnym miasta. Szansa opadów to maksymalna wartość w danym dniu.")
        }
    }
}
