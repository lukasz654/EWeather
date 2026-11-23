import SwiftUI
import WeatherDomain

struct HourlyForecastSection: View {
    let forecast: Forecast

    var body: some View {
        let repeatedTimes = WeatherFormatting.repeatedLocalTimes(in: forecast.hours.map(\.time), timeZoneIdentifier: forecast.timeZoneIdentifier)
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
    }
}
