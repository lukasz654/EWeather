import WeatherDomain
import SwiftUI

struct SearchView: View {
    @Bindable var model: SearchViewModel
    @State private var retryCount = 0

    var body: some View {
        List {
            Section {
                TextField("Nazwa miasta", text: Binding(get: { model.query }, set: { model.updateQuery($0) }))
                    .textContentType(.addressCity)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityLabel("Wyszukaj miasto")
                    .onSubmit { retryCount += 1 }
            } header: {
                Label("Wyszukaj miasto", systemImage: "magnifyingglass")
            } footer: {
                if let message = model.validationMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                } else {
                    Text("Wpisz co najmniej dwie litery, np. Bielsko-Biała lub Nowy Sącz.")
                }
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

            if let message = model.historyMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Button("Spróbuj ponownie") { model.retryHistory() }
                }
            }
        }
        .navigationTitle("Pogoda")
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { SearchAttributionView() }
        .task(id: SearchRequest(query: model.query, retryCount: retryCount)) {
            await model.search()
        }
    }
}

private struct SearchAttributionView: View {
    var body: some View {
        HStack {
            Link("Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
            Text("·").accessibilityHidden(true)
            Link("GeoNames", destination: URL(string: "https://www.geonames.org/")!)
        }
        .font(.footnote)
        .frame(maxWidth: .infinity)
        .padding()
        .background(.bar)
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
