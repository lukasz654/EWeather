import SwiftUI

struct ForecastAttributionSection: View {
    var body: some View {
        Section {
            Link(destination: URL(string: "https://open-meteo.com/")!) {
                Label("Open-Meteo", systemImage: "arrow.up.right.square")
            }
            Link("Licencja CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
            Link("Dane lokalizacji: GeoNames", destination: URL(string: "https://www.geonames.org/")!)
        } header: {
            Text("Źródło danych")
        } footer: {
            Text("Prognoza pochodzi z modeli pogodowych Open-Meteo.")
        }
    }
}
