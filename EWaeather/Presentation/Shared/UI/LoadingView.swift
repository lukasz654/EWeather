import SwiftUI

struct LoadingView: View {
    let message: String

    var body: some View {
        ProgressView(message)
            .frame(maxWidth: .infinity, minHeight: 180)
            .padding()
            .accessibilityLabel(message)
    }
}
