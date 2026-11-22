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
                StatusView(title: "Brak wyników", systemImage: "magnifyingglass", message: "Nie znaleziono miasta. Sprawdź nazwę lub wpisz inną.")
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

private struct SearchRequest: Equatable {
    let query: String
    let retryCount: Int
}
