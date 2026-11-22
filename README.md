# EWaeather

EWaeather is a native iOS weather app for the Empik iOS recruitment task. Its purpose is to help users find a city and check its weather forecast using Open-Meteo.

The app uses SwiftUI, native navigation, system icons and system colors. The interface is in Polish and follows the device appearance, including Dark Mode.

## Development status

Stage 3 connects city search to Open-Meteo and saves selected cities in UserDefaults. The search screen no longer uses a fixed sample list. **Weather details still use sample data**, with a visible label. Live weather details are planned for stage 4.

- Search city names, including Bielsko-Biała and Nowy Sącz, with input validation and automatic search after a short pause.
- Open a city from search results or saved history and return with the system back button.
- Keep selected cities in history across app launches. Selecting a saved city moves it to the top.
- View sample temperature, cloud cover, rain probability with its time range, and 24 hourly temperatures.

The live search integration has been tested with controlled API responses.

## Run the app

1. Open `EWaeather.xcodeproj` in Xcode 26 or 27.
2. Select the `EWaeather` scheme and an iPhone simulator with iOS 17 or later.
3. Run the app. No API key or external package is needed for this stage.

For a physical device, select your signing team in the app target settings.

## Architecture

The app follows Clean Architecture with MVVM in the presentation layer and SOLID principles:

- `Domain`: city and forecast models, plus small repository contracts.
- `Application`: search, forecast and history use cases that depend on those contracts. The forecast use case selects the next 24 hourly steps and the rain time range. History use cases control order and duplicates.
- `Data/Remote`: URLSession transport, HTTP handling, Open-Meteo requests, response types and mapping.
- `Data/Repositories`: remote implementations of the city and weather contracts.
- `Data/Local`: UserDefaults history storage with its own versioned JSON format.
- `Data/Sample`: local sample weather and in-memory history. These do not call Open-Meteo or change saved history.
- `Presentation`: observable screen models, SwiftUI views and display formatting.
- `App`: creates dependencies and connects the screens.

The inner layers do not depend on SwiftUI, HTTP or storage details. These are logical boundaries in one app target.

Small contracts keep city search separate from weather loading. The remote adapters can replace the sample provider without changing the screen models. The network transport is injected, so error handling can be tested without a server. Response types and provider field names stay in Data; the forecast selection rule stays in Application.

## Search and history behavior

- City names accept Unicode letters, including Polish letters, ordinary spaces and the standard hyphen. Unicode text is normalized. Digits, other punctuation, emoji, tabs and line breaks are rejected. An invalid edit keeps the last valid text and shows a message.
- Search starts from two letters after trimming outer spaces. Shorter input keeps the initial state and history visible. Input is checked again in the use case before a request can be sent.
- A 300 ms pause reduces requests while typing. SwiftUI cancels the previous search task when the query changes. A request identifier also prevents older results from changing the current screen, even if a provider ignores cancellation.
- History contains selected cities, not typed query fragments. It is ordered by the latest selection, with one record per location identifier and no fixed limit. Cities with the same name and different identifiers remain separate.
- History stores the city identity, coordinates and available location details. Read and write contracts are separate. Synchronous history operations share the main actor so read-modify-write steps cannot interleave.
- A history read or write failure shows a separate message and a retry button. It does not block navigation. A failed save keeps the city visible for the current session. Corrupted stored data is reported and is not silently replaced.

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

Use Product > Test or Command-U to run `EWaeatherTests`. The tests cover input validation, debounce, history order and restoration, storage failures, empty states, retry, cancellation, older search results, missing values, city time zones, forecast selection, URL parameters, response mapping and HTTP 400/429/5xx errors.

Validation so far: the app and iOS test target compile with Xcode 27.1. Sixty-seven tests passed on macOS using copies of the same non-UI source and test files. An integration test follows a controlled search response through selection, UserDefaults storage and a recreated screen model. These checks do not replace an iOS launch or an app restart check.

Three user screenshots from an iPhone 18 Pro simulator were reviewed in light appearance: sample history, empty search results and weather details. The review led to a smaller empty-results message and shorter forecast dates. The updated layouts still need a visual check. Dark Mode, a smaller phone, larger text and the remaining screen states also need review.

Before accepting stage 3 on iOS, check Polish names, rejected typing and pasted text, rapid query changes, offline and retry states, and history after selecting a city and restarting the app. Review the updated screens in light and dark appearance. The real service response remains unverified here.

## Data source

City search uses [Open-Meteo](https://open-meteo.com/), with location data from [GeoNames](https://www.geonames.org/). Live weather will also come from Open-Meteo, with attribution under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The weather values currently shown in details are created locally.
