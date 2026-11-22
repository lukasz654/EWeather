import SwiftUI

struct SearchEmptyResultsView: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 6) {
                Text("Brak wyników")
                    .font(.headline)
                Text("Nie znaleziono miasta. Sprawdź nazwę lub wpisz inną.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}
