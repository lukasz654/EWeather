/// Provider-independent conditions. Unknown or missing codes do not imply clear weather.
public enum DailyWeatherCondition: CaseIterable, Equatable, Sendable {
    case clearSky, mainlyClear, partlyCloudy, overcast, fog, rimeFog
    case lightDrizzle, moderateDrizzle, denseDrizzle
    case lightFreezingDrizzle, denseFreezingDrizzle
    case lightRain, moderateRain, heavyRain, lightFreezingRain, heavyFreezingRain
    case lightSnow, moderateSnow, heavySnow, snowGrains
    case lightRainShowers, moderateRainShowers, violentRainShowers
    case lightSnowShowers, heavySnowShowers
    case thunderstorm, thunderstormWithLightHail, heavyThunderstorm, thunderstormWithHeavyHail
    case unknown
}
