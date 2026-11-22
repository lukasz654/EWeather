# EWaeather

EWaeather is a native iOS weather app for the Empik iOS recruitment task. Its purpose is to help users find a city and check its weather forecast using Open-Meteo.

The app uses SwiftUI, native navigation, system icons and system colors. The interface is in Polish and follows the device appearance, including Dark Mode.

## Development status

Stage 1 provides the search and weather details screens with **sample data only**. A visible label marks these values. They are not real weather forecasts.

- Search the sample cities: Bielsko-Biała, Nowy Sącz and Warszawa.
- Open a city from search results or the sample history and return with the system back button.
- View sample temperature, cloud cover, rain probability with its time range, and 24 hourly temperatures.

Live API requests, full input validation and saved history across app launches are planned for later stages. The current history is a fixed sample list.

## Run the app

1. Open `EWaeather.xcodeproj` in Xcode 26 or 27.
2. Select the `EWaeather` scheme and an iPhone simulator with iOS 17 or later.
3. Run the app. No API key or external package is needed for this stage.

For a physical device, select your signing team in the app target settings.

## Architecture

The app follows Clean Architecture with MVVM in the presentation layer and SOLID principles:

- `Domain`: city and forecast models, plus small repository contracts.
- `Application`: search and forecast use cases that depend on those contracts.
- `Data/Sample`: a local sample provider. It does not call Open-Meteo.
- `Presentation`: observable screen models, SwiftUI views and display formatting.
- `App`: creates dependencies and connects the screens.

The inner layers do not depend on SwiftUI or storage details. These are logical boundaries in one app target. Storage and live API adapters have not been added yet.

## Tests

Use Product > Test or Command-U to run `EWaeatherTests`. The tests cover empty states, retry, cancellation, older search results, missing values and city time zones.

## Planned data source

Live weather will come from [Open-Meteo](https://open-meteo.com/), with attribution under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). City lookup uses location data from [GeoNames](https://www.geonames.org/). The current sample values are created locally.
