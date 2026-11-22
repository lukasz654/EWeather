import SwiftUI
import WeatherDomain

struct FailureView: View {
    let failure: WeatherFailure
    let retry: () -> Void

    var body: some View {
        switch failure {
        case .offline:
            StatusView(title: "Brak połączenia", systemImage: "wifi.slash", message: "Sprawdź połączenie z internetem i spróbuj ponownie.", retry: retry)
        case .unavailable:
            StatusView(title: "Nie udało się pobrać danych", systemImage: "exclamationmark.icloud", message: "Usługa jest chwilowo niedostępna. Spróbuj ponownie.", retry: retry)
        case .invalidData:
            StatusView(title: "Nie można odczytać danych", systemImage: "exclamationmark.triangle", message: "Otrzymane dane są nieprawidłowe. Spróbuj ponownie.", retry: retry)
        }
    }
}
