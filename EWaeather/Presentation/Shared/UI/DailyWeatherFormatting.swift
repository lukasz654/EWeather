import Foundation
import WeatherDomain

enum DailyWeatherFormatting {
    static func day(_ day: ForecastDay) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) else {
            return "Data niedostępna"
        }
        // The API supplies a calendar date. Do not reinterpret it in the device's time zone.
        return date.formatted(Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: "pl_PL"), calendar: calendar, timeZone: .gmt).weekday(.wide).day().month(.abbreviated))
    }

    static func description(_ condition: DailyWeatherCondition) -> String {
        switch condition {
        case .clearSky: "Bezchmurnie"
        case .mainlyClear: "Przeważnie bezchmurnie"
        case .partlyCloudy: "Częściowe zachmurzenie"
        case .overcast: "Pochmurno"
        case .fog: "Mgła"
        case .rimeFog: "Mgła osadzająca szadź"
        case .lightDrizzle: "Słaba mżawka"
        case .moderateDrizzle: "Umiarkowana mżawka"
        case .denseDrizzle: "Gęsta mżawka"
        case .lightFreezingDrizzle: "Słaba marznąca mżawka"
        case .denseFreezingDrizzle: "Gęsta marznąca mżawka"
        case .lightRain: "Słaby deszcz"
        case .moderateRain: "Umiarkowany deszcz"
        case .heavyRain: "Silny deszcz"
        case .lightFreezingRain: "Słaby marznący deszcz"
        case .heavyFreezingRain: "Silny marznący deszcz"
        case .lightSnow: "Słabe opady śniegu"
        case .moderateSnow: "Umiarkowane opady śniegu"
        case .heavySnow: "Intensywne opady śniegu"
        case .snowGrains: "Śnieg ziarnisty"
        case .lightRainShowers: "Słabe przelotne opady deszczu"
        case .moderateRainShowers: "Umiarkowane przelotne opady deszczu"
        case .violentRainShowers: "Gwałtowne przelotne opady deszczu"
        case .lightSnowShowers: "Słabe przelotne opady śniegu"
        case .heavySnowShowers: "Silne przelotne opady śniegu"
        case .thunderstorm: "Burza"
        case .thunderstormWithLightHail: "Burza ze słabym gradem"
        case .heavyThunderstorm: "Silna burza"
        case .thunderstormWithHeavyHail: "Burza z silnym gradem"
        case .unknown: "Brak opisu pogody"
        }
    }

    static func systemImage(_ condition: DailyWeatherCondition) -> String {
        switch condition {
        case .clearSky, .mainlyClear: "sun.max"
        case .partlyCloudy: "cloud.sun"
        case .overcast: "cloud"
        case .fog, .rimeFog: "cloud.fog"
        case .lightDrizzle, .moderateDrizzle, .denseDrizzle: "cloud.drizzle"
        case .lightFreezingDrizzle, .denseFreezingDrizzle, .lightFreezingRain, .heavyFreezingRain: "cloud.sleet"
        case .lightRain, .moderateRain, .lightRainShowers, .moderateRainShowers: "cloud.rain"
        case .heavyRain, .violentRainShowers: "cloud.heavyrain"
        case .lightSnow, .moderateSnow, .heavySnow, .snowGrains, .lightSnowShowers, .heavySnowShowers: "cloud.snow"
        case .thunderstorm, .heavyThunderstorm: "cloud.bolt.rain"
        case .thunderstormWithLightHail, .thunderstormWithHeavyHail: "cloud.hail"
        case .unknown: "questionmark.circle"
        }
    }
}
