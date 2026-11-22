import SwiftUI

struct StatusView: View {
    let title: String
    let systemImage: String
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let retry {
                Button("Spróbuj ponownie", action: retry)
                    .buttonStyle(.bordered)
            }
        }
    }
}
