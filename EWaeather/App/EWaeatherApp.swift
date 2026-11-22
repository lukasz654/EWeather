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
    private let composition: AppComposition
    @State private var searchModel: SearchViewModel
    @State private var path: [City] = []

    init(composition: AppComposition = AppComposition()) {
        self.composition = composition
        _searchModel = State(initialValue: composition.makeSearchModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            SearchView(model: searchModel)
                .navigationDestination(for: City.self) { city in
                    ForecastView(model: composition.makeForecastModel(city: city))
                }
        }
        .onChange(of: path) { oldPath, newPath in
            if newPath.count > oldPath.count, let city = newPath.last {
                searchModel.remember(city)
            }
        }
    }
}
