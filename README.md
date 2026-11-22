# EWaeather

EWaeather is a native iOS weather app for the Empik iOS recruitment task. Its purpose is to help users find a city and check its weather forecast using Open-Meteo.

The app uses SwiftUI, native navigation, system icons and system colors. The interface is in Polish and follows the device appearance, including Dark Mode.

## Development status

Stages 3 and 4 connect city search and weather details to Open-Meteo. Selected cities are saved in UserDefaults. The running app does not use sample city lists or weather values; samples are kept in tests.

- Search city names, including Bielsko-Biała and Nowy Sącz, with input validation and automatic search after a short pause.
- Open a city from search results or saved history and return with the system back button.
- Keep selected cities in history across app launches. Selecting a saved city moves it to the top.
- View current temperature, cloud cover, rain probability with its time range, and up to 24 hourly temperatures.

The search and weather integrations have been tested with controlled API responses.

## Run the app

1. Open `EWaeather.xcodeproj` in Xcode 26 or 27.
2. Select the `EWaeather` scheme and an iPhone simulator with iOS 17 or later.
3. Run the app. No API key or external package is needed for this stage.

For a physical device, select your signing team in the app target settings. Search and weather loading need an internet connection. Saved city history remains available offline; weather is not cached.

## Architecture

The app follows Clean Architecture with MVVM in the presentation layer and SOLID principles:

- `Domain`: city and forecast models, plus small repository contracts.
- `Application`: search, forecast and history use cases that depend on those contracts. The forecast use case selects the next 24 hourly steps and the rain time range. History use cases control order and duplicates.
- `Data/Remote`: URLSession transport, HTTP handling, Open-Meteo requests, response types and mapping.
- `Data/Repositories`: remote implementations of the city and weather contracts.
- `Data/Local`: UserDefaults history storage with its own versioned JSON format.
- `EWaeatherTests`: local sample city search, weather and in-memory history. These do not call Open-Meteo or change saved history.
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

## Weather details behavior

- Opening details loads weather using the selected city's coordinates. A different city gets its own screen model and request. Returning to search and opening details again creates a new request; an already loaded model keeps its values when it reappears.
- The screen shows loading, weather values, an empty result, offline or a service/data error. Empty and failed states have a retry button. Retries run in the SwiftUI view task, which is cancelled when the screen closes.
- Closing the screen also invalidates its request identifier. A late response cannot change a newer load, even if the provider ignores cancellation. Concurrent duplicate loads are ignored.
- Missing values show `Brak danych`; missing hourly values keep their timestamp. Current conditions can still be shown when hourly data is unavailable. If current values and the selected future hours contain no weather values, the screen shows an empty result.
- Dates and time ranges use the forecast city's time zone. Repeated local clock hours show UTC offsets so they can be told apart. Rain time ranges also show offsets if a clock change occurs inside the interval.
- The live screen credits Open-Meteo, CC BY 4.0 and GeoNames.

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

Use Product > Test or Command-U to run `EWaeatherTests`. The tests cover input validation, debounce, history order and restoration, storage failures, empty states, retry, cancellation, older responses, missing values, city time zones, midnight and clock changes, forecast selection, URL parameters, response mapping and HTTP 400/429/5xx errors.

Validation so far: the app and iOS test target compile with Xcode 27.1. Eighty-three tests passed on macOS using copies of the same non-UI source and test files, including app composition. Integration tests follow controlled HTTP responses through search and saved history, and through weather loading, different cities, reopening details, errors and retry. These checks do not replace an iOS launch or an app restart check.

Three user screenshots from an iPhone 18 Pro simulator were reviewed in light appearance: sample history, empty search results and weather details. The review led to a smaller empty-results message and shorter forecast dates. The updated layouts still need a visual check. Dark Mode, a smaller phone, larger text and the remaining screen states also need review.

Before accepting stages 3 and 4 on iOS, check Polish names, rejected typing and pasted text, rapid query changes, offline and retry states, and history after selecting a city and restarting the app. Check weather for different cities, all four required weather elements, back navigation, reopening details and leaving during a load or retry. Review the updated screens in light and dark appearance. Real service responses remain unverified here.

## Data source

City search and weather use [Open-Meteo](https://open-meteo.com/), with weather attribution under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Location data comes from [GeoNames](https://www.geonames.org/). Test weather values are created locally.
