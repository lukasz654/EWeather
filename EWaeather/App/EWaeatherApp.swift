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
