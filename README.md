# EWaeather

EWaeather is a native iOS weather app for the Empik iOS recruitment task. Its purpose is to help users find a city and check its weather forecast using Open-Meteo.

The app uses SwiftUI, native navigation, system icons and system colors. The interface is in Polish and follows the device appearance, including Dark Mode.

## Development status

Stage 1 provides the search and weather details screens with **sample data only**. Stage 2 adds the HTTP client and Open-Meteo repositories. The running app still uses sample data until the search and forecast integration stages. A visible label marks these values. They are not real weather forecasts.

- Search the sample cities: Bielsko-Biała, Nowy Sącz and Warszawa.
- Open a city from search results or the sample history and return with the system back button.
- View sample temperature, cloud cover, rain probability with its time range, and 24 hourly temperatures.

The remote adapters can request and map city and weather responses, but they are not connected to the screens yet. Full input validation and saved history across app launches are also planned for later stages. The current history is a fixed sample list.

## Run the app

1. Open `EWaeather.xcodeproj` in Xcode 26 or 27.
2. Select the `EWaeather` scheme and an iPhone simulator with iOS 17 or later.
3. Run the app. No API key or external package is needed for this stage.

For a physical device, select your signing team in the app target settings.

## Architecture

The app follows Clean Architecture with MVVM in the presentation layer and SOLID principles:

- `Domain`: city and forecast models, plus small repository contracts.
- `Application`: search and forecast use cases that depend on those contracts. The forecast use case selects the next 24 hourly steps and the rain time range.
- `Data/Remote`: URLSession transport, HTTP handling, Open-Meteo requests, response types and mapping.
- `Data/Repositories`: remote implementations of the city and weather contracts.
- `Data/Sample`: a local sample provider. It does not call Open-Meteo.
- `Presentation`: observable screen models, SwiftUI views and display formatting.
- `App`: creates dependencies and connects the screens.

The inner layers do not depend on SwiftUI, HTTP or storage details. These are logical boundaries in one app target. Local history storage has not been added yet.

Small contracts keep city search separate from weather loading. The remote adapters can replace the sample provider without changing the screen models. The network transport is injected, so error handling can be tested without a server. Response types and provider field names stay in Data; the forecast selection rule stays in Application.

## API decisions

- City search uses HTTPS, `URLComponents`, Polish result names and up to 10 matches. It is not limited to Poland.
- Weather requests ask for current temperature and cloud cover, plus 25 hourly temperature and rain probability steps. Only fields used by the app are requested.
- Temperatures use Celsius. Unix timestamps stay absolute; display formatting uses the forecast's time zone. Unknown forecast zones and unexpected units are data errors.
- The use case selects up to 24 steps strictly after the current weather timestamp. Rain probability comes from the first selected step and refers to the hour ending at that timestamp.
- Missing values stay missing. They are never changed to zero or replaced with a later hour. Mismatched hourly arrays, duplicate times and percentages outside 0–100 are rejected.
- Missing search region or country is allowed. If a search result has no time zone, its model uses GMT as a fallback. Weather details use the time zone returned by the forecast request.
- HTTP errors are separate from data errors and offline failures. Timeouts and other connection failures are service errors. Cancellation is passed back without a user error. Server messages stay in the data layer.

The request contract follows the [Geocoding API documentation](https://open-meteo.com/en/docs/geocoding-api) and [Forecast API documentation](https://open-meteo.com/en/docs). Test responses are written from that contract; they are not recordings from the live service.

## Tests

Use Product > Test or Command-U to run `EWaeatherTests`. The tests cover empty states, retry, cancellation, older search results, missing values, city time zones, forecast selection, URL parameters, response mapping and HTTP 400/429/5xx errors.

Validation so far: the app and iOS test target compile with Xcode 27.1. Thirty-seven tests passed on macOS using copies of the same non-UI source and test files, including the HTTP client and repositories.

Three user screenshots from an iPhone 18 Pro simulator were reviewed in light appearance: sample history, empty search results and weather details. The review led to a smaller empty-results message and shorter forecast dates. The updated layouts still need a visual check. Dark Mode, a smaller phone, larger text and the remaining screen states also need review.

## Planned data source

Live weather will come from [Open-Meteo](https://open-meteo.com/), with attribution under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). City lookup uses location data from [GeoNames](https://www.geonames.org/). The current sample values are created locally.
