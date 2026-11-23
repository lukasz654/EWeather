import SwiftUI
import WeatherDomain

struct HourlyForecastRangePicker: View {
    @Binding var selection: HourlyForecastRange
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    private var picker: some View {
        Picker("Zakres prognozy godzinowej", selection: $selection) {
            ForEach(HourlyForecastRange.allCases, id: \.self) { range in
                Text("\(range.rawValue) h").tag(range)
            }
        }
        .accessibilityLabel("Zakres prognozy godzinowej")
    }
}
