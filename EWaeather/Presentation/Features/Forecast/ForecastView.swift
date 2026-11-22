import WeatherDomain
import SwiftUI

struct ForecastView: View {
    @State var model: ForecastViewModel
    @State private var reloadCount = 0

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
                forecastSections(forecast)
            case .empty:
                StatusView(title: "Brak prognozy", systemImage: "cloud", message: "Prognoza dla tego miasta jest niedostępna.", retry: reload)
                    .listRowBackground(Color.clear)
            case .failed(let failure):
                FailureView(failure: failure, retry: reload)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(model.city.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: reloadCount) {
            await model.loadIfNeeded()
        }
        .onDisappear { model.cancelLoading() }
    }

    @ViewBuilder
    private func forecastSections(_ forecast: Forecast) -> some View {
        let repeatedTimes = WeatherFormatting.repeatedLocalTimes(in: forecast.hours.map(\.time), timeZoneIdentifier: forecast.timeZoneIdentifier)
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Temperatura", systemImage: "thermometer.medium")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(WeatherFormatting.temperature(forecast.temperature))
                    .font(.largeTitle.weight(.semibold))
                    .accessibilityLabel("Temperatura \(WeatherFormatting.temperature(forecast.temperature))")
                Text(WeatherFormatting.dateAndTime(forecast.updatedAt, timeZoneIdentifier: forecast.timeZoneIdentifier))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            metric(title: "Zachmurzenie", systemImage: "cloud", value: WeatherFormatting.percent(forecast.cloudCover))
            VStack(alignment: .leading, spacing: 8) {
                metric(title: "Szansa opadów", systemImage: "drop", value: WeatherFormatting.percent(forecast.precipitationProbability))
                Text(WeatherFormatting.interval(forecast.precipitationInterval, timeZoneIdentifier: forecast.timeZoneIdentifier))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Warunki pogodowe")
        } footer: {
            Text("Wszystkie godziny podano w czasie lokalnym miasta.")
        }

        Section("Najbliższe godziny") {
            if forecast.hours.isEmpty {
                Text("Brak prognozy godzinowej")
                    .foregroundStyle(.secondary)
            }
            ForEach(forecast.hours) { hour in
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text(WeatherFormatting.dateAndTime(hour.time, timeZoneIdentifier: forecast.timeZoneIdentifier, includesUTCOffset: repeatedTimes.contains(hour.time)))
                        Spacer(minLength: 16)
                        Text(WeatherFormatting.temperature(hour.temperature)).fontWeight(.medium)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(WeatherFormatting.dateAndTime(hour.time, timeZoneIdentifier: forecast.timeZoneIdentifier, includesUTCOffset: repeatedTimes.contains(hour.time)))
                        Text(WeatherFormatting.temperature(hour.temperature)).fontWeight(.medium)
                    }
                }
                .monospacedDigit()
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }

        Section {
            Link(destination: URL(string: "https://open-meteo.com/")!) {
                Label("Open-Meteo", systemImage: "arrow.up.right.square")
            }
            Link("Licencja CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
            Link("Dane lokalizacji: GeoNames", destination: URL(string: "https://www.geonames.org/")!)
        } header: {
            Text("Źródło danych")
        } footer: {
            Text("Prognoza pochodzi z modeli pogodowych Open-Meteo.")
        }
    }

    private func metric(title: String, systemImage: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.medium)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func reload() {
        reloadCount += 1
    }
}
