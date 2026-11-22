import SwiftUI

struct SearchAttributionView: View {
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
