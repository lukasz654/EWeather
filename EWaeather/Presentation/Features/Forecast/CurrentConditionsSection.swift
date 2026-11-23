import SwiftUI
import WeatherDomain

struct CurrentConditionsSection: View {
    let forecast: Forecast

    var body: some View {
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
}
