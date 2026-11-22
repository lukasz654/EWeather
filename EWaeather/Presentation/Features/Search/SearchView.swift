import SwiftUI

struct SearchView: View {
    @Bindable var model: SearchViewModel
    @State private var retryCount = 0

    var body: some View {
        List {
            Section {
                TextField("Nazwa miasta", text: $model.query)
                    .textContentType(.addressCity)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityLabel("Wyszukaj miasto")
            } header: {
                Label("Wyszukaj miasto", systemImage: "magnifyingglass")
            } footer: {
                Text("Wpisz nazwę miasta, np. Bielsko-Biała lub Nowy Sącz.")
            }

            switch model.state {
            case .idle:
                if model.history.isEmpty {
                    StatusView(title: "Sprawdź pogodę w mieście", systemImage: "cloud.sun", message: "Wpisz nazwę miasta, aby zobaczyć prognozę.")
                        .listRowBackground(Color.clear)
                }
            case .loading:
                LoadingView(message: "Wyszukiwanie miast…")
                    .listRowBackground(Color.clear)
            case .results(let cities):
                Section("Wyniki wyszukiwania") {
                    ForEach(cities) { city in
                        NavigationLink(value: city) { CityRow(city: city) }
                    }
                }
            case .empty:
                SearchEmptyResultsView()
                    .listRowBackground(Color.clear)
            case .failed(let failure):
                FailureView(failure: failure) { retryCount += 1 }
                    .listRowBackground(Color.clear)
            }

            if !model.history.isEmpty {
                Section("Ostatnio wybrane") {
                    ForEach(model.history) { city in
                        NavigationLink(value: city) { CityRow(city: city, systemImage: "clock") }
                    }
                }
            }
        }
        .navigationTitle("Pogoda")
        .task(id: SearchRequest(query: model.query, retryCount: retryCount)) {
            await model.search()
        }
    }
}

private struct SearchEmptyResultsView: View {
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

private struct SearchRequest: Equatable {
    let query: String
    let retryCount: Int
}
