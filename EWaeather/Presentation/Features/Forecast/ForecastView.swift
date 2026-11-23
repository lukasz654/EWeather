import WeatherDomain
import SwiftUI

struct ForecastView: View {
    @State var model: ForecastViewModel
    @State var dailyModel: DailyForecastViewModel
    @State private var reloadCount = 0
    @State private var dailyReloadCount = 0

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
                displayedRange: model.loadedRange,
                updateState: model.updateState,
                range: Binding(get: { model.range }, set: { model.selectRange($0) }),
                retry: reload
            )
            ForecastAttributionSection()
        }
        .navigationTitle(model.city.name)
        .navigationBarTitleDisplayMode(.inline)
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

    private func reloadDaily() { dailyReloadCount += 1 }

    private func reload() {
        reloadCount += 1
    }
}

private struct ForecastRequest: Equatable {
    let range: HourlyForecastRange
    let retryCount: Int
}
