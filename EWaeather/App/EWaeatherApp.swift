import SwiftUI

@main
struct EWaeatherApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentUnavailableView("Pogoda", systemImage: "cloud.sun", description: Text("Wyszukaj miasto, aby sprawdzić prognozę."))
                    .navigationTitle("EWaeather")
            }
            .environment(\.locale, Locale(identifier: "pl_PL"))
        }
    }
}
