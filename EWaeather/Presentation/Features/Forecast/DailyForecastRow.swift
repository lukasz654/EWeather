import SwiftUI
import WeatherDomain

struct DailyForecastRow: View {
    let forecast: DailyForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(DailyWeatherFormatting.day(forecast.day))
                .font(.headline)
            Label(DailyWeatherFormatting.description(forecast.condition), systemImage: DailyWeatherFormatting.systemImage(forecast.condition))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(minimumLabel)
                    Spacer(minLength: 16)
                    Text(maximumLabel)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(minimumLabel)
                    Text(maximumLabel)
                }
            }
            .font(.subheadline)
            .monospacedDigit()
            Label("Maks. szansa opadów: \(WeatherFormatting.percent(forecast.maximumPrecipitationProbability))", systemImage: "drop")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var minimumLabel: String { "Minimum: \(WeatherFormatting.temperature(forecast.minimumTemperature))" }
    private var maximumLabel: String { "Maksimum: \(WeatherFormatting.temperature(forecast.maximumTemperature))" }
}
