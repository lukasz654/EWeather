import SwiftUI

struct CityRow: View {
    let city: City
    var systemImage = "mappin.and.ellipse"

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(city.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                let location = [city.region, city.country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                if !location.isEmpty {
                    Text(location)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .combine)
    }
}
