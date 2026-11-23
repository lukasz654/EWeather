import WeatherDomain
import SwiftUI

struct ForecastView: View {
    @State var model: ForecastViewModel
    @State var dailyModel: DailyForecastViewModel
    @State private var reloadCount = 0
    @State private var dailyReloadCount = 0
    @State private var isShowingUpdateAlert = false

    var body: some View {
        List {
            Section {
                CityRow(city: model.city)
            }
            switch model.state {
            case .idle, .loading:
                LoadingView(message: "Pobieranie prognozy…")
                    .listRowBackground(Color.clear)
            case .loaded(let forecast):
                CurrentConditionsSection(forecast: forecast)
            case .empty:
                StatusView(title: "Brak prognozy", systemImage: "cloud", message: "Prognoza dla tego miasta jest niedostępna.", retry: reload)
                    .listRowBackground(Color.clear)
            case .failed(let failure):
                FailureView(failure: failure, retry: reload)
                    .listRowBackground(Color.clear)
            }
            DailyForecastSection(model: dailyModel, retry: reloadDaily)
            HourlyForecastSection(
                forecast: loadedForecast,
                range: Binding(get: { model.range }, set: { model.selectRange($0) })
            )
            ForecastAttributionSection()
        }
        .navigationTitle(model.city.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: model.updateState) { _, state in
            switch state {
            case .empty, .failed: isShowingUpdateAlert = true
            case .idle, .loading: isShowingUpdateAlert = false
            }
        }
        .alert(updateAlertTitle, isPresented: $isShowingUpdateAlert) {
            Button("Spróbuj ponownie", action: reload)
            Button("Zachowaj poprzedni zakres", role: .cancel) {
                if let range = model.loadedRange { model.selectRange(range) }
            }
        } message: {
            Text("Poprzednia prognoza pozostaje widoczna. Spróbuj ponownie lub zachowaj poprzedni zakres godzin.")
        }
        .task(id: ForecastRequest(range: model.range, retryCount: reloadCount)) {
            await model.loadIfNeeded()
        }
        .task(id: dailyReloadCount) {
            await dailyModel.loadIfNeeded()
        }
        .onDisappear {
            model.cancelLoading()
            dailyModel.cancelLoading()
        }
    }

    private var loadedForecast: Forecast? {
        guard case .loaded(let forecast) = model.state else { return nil }
        return forecast
    }

    private var updateAlertTitle: String {
        switch model.updateState {
        case .empty: "Brak nowej prognozy"
        case .failed(.offline): "Brak połączenia"
        case .failed(.unavailable): "Nie udało się zaktualizować prognozy"
        case .failed(.invalidData): "Nie można odczytać nowej prognozy"
        case .idle, .loading: "Aktualizacja prognozy"
        }
    }

    private func reloadDaily() { dailyReloadCount += 1 }

    private func reload() {
        reloadCount += 1
    }
}

private struct ForecastRequest: Equatable {
    let range: HourlyForecastRange
    let retryCount: Int
}
