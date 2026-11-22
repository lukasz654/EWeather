import SwiftUI

@main
struct EWaeatherApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(\.locale, Locale(identifier: "pl_PL"))
        }
    }
}

struct AppRootView: View {
    private let composition = AppComposition()
    @State private var searchModel = AppComposition().makeSearchModel()

    var body: some View {
        NavigationStack {
            SearchView(model: searchModel)
                .navigationDestination(for: City.self) { city in
                    ForecastView(model: composition.makeForecastModel(city: city))
                }
        }
    }
}
