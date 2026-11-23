# Application behavior and API decisions

This document describes implemented behavior and technical choices. These choices are separate from the recruitment task's requirements. Source code and tests define the exact implementation.

## Search and history

- City names accept Unicode letters, including Polish letters, ordinary spaces and the standard hyphen. Unicode text is normalized. Digits, other punctuation, emoji, tabs and line breaks are rejected. An invalid edit keeps the last valid text and shows a message.
- Search starts from two letters after trimming outer spaces. Shorter input keeps the initial state and history visible. Input is checked again in the use case before a request can be sent.
- A 300 ms pause reduces requests while typing. SwiftUI cancels the previous search task when the query changes. A request identifier also prevents older results from changing the current screen, even if a provider ignores cancellation.
- History contains selected cities, not typed query fragments. It is ordered by the latest selection, with one record per location identifier and no fixed limit. Cities with the same name and different identifiers remain separate.
- History stores the city identity, coordinates and available location details. Read and write contracts are separate. Synchronous history operations share the main actor so read-modify-write steps cannot interleave.
- A history read or write failure shows a separate message and a retry button. It does not block navigation. A failed save keeps the city visible for the current session. Corrupted stored data is reported and is not silently replaced.

## Current and hourly weather

- Opening details loads weather using the selected city's coordinates. A different city gets its own screen model and request. Returning to search and opening details again creates a new request; an already loaded model keeps its values when it reappears.
- Hourly rows show the time and temperature. A native picker offers 3, 5, 8 and 12 hours; each new details screen starts with 3 hours. Accessibility text sizes use a native menu instead of segments.
- Changing the window starts a new hourly request and immediately invalidates older requests. Current conditions and hourly rows keep their last loaded values until the new response arrives. Daily weather stays independent.
- A failed or empty update keeps the previous forecast and shows a native alert. Users can retry the selected range or return the picker to the last loaded range. Returning to the loaded range does not make another request. Late responses cannot replace the selected range.
- The screen shows loading, weather values, an empty result, offline or a service/data error. Empty and failed states have a retry button. Retries run in the SwiftUI view task, which is cancelled when the screen closes.
- Closing the screen also invalidates its request identifier. A late response cannot change a newer load, even if the provider ignores cancellation. Concurrent duplicate loads are ignored.
- Missing values show `Brak danych`; missing hourly values keep their timestamp. Current conditions can still be shown when hourly data is unavailable. If the first response contains no current or future weather values, the screen shows an empty result. An empty update keeps the last loaded forecast and reports that no new data was received.
- Dates and time ranges use the forecast city's time zone. Repeated local clock hours show UTC offsets so they can be told apart. Rain time ranges also show offsets if a clock change occurs inside the interval.
- The live screen credits Open-Meteo, CC BY 4.0 and GeoNames.

## Forecast for three days

- A separate section appears between current conditions and the hourly list. It requests three days beginning with the city's current day. If the provider has fewer days, the app shows the available data.
- Each row shows the local date and weekday, a Polish weather description with an SF Symbol, minimum and maximum temperatures, and the maximum precipitation probability for that day. The daily condition describes the most severe weather expected that day.
- Daily weather has its own repository, use case, screen model, request, loading state and retry action. A daily error keeps current and hourly weather available. Daily weather can also load when the current forecast fails.
- Both requests belong to separate SwiftUI view tasks. Leaving details cancels them and invalidates unfinished loads. Loaded models keep their values when they reappear; reopening details creates new models and requests.
- Missing values show `Brak danych`. Missing or unknown weather codes show `Brak opisu pogody` and a question mark symbol. A known condition can be shown without temperatures. A selected window with no weather values or known conditions produces the empty state.
- Daily dates are calendar dates, not timestamps. The mapper reads the API's date-only ISO strings without shifting them into the device's time zone. Gregorian date validation, clock changes, month and year boundaries are covered by tests.

## API decisions

- City search uses HTTPS, `URLComponents`, Polish result names and up to 10 matches. It is not limited to Poland.
- Hourly requests ask for current temperature and cloud cover, plus hourly temperature and rain probability. The selected window controls `forecast_hours`: 3/5/8/12 displayed hours request 4/6/9/13 steps, including the current step that may need to be filtered out.
- Temperatures use Celsius. Unix timestamps stay absolute; display formatting uses the forecast's time zone. Unknown forecast zones and unexpected units are data errors.
- The same `HourlyForecastRange` value controls the request and the use case limit. The use case selects up to the chosen number of steps strictly after the current weather timestamp. Rain probability comes from the first selected step and refers to the hour ending at that timestamp.
- Daily requests use `forecast_days=3`, `timezone=auto`, `timeformat=iso8601` and only `weather_code`, `temperature_2m_min`, `temperature_2m_max` and `precipitation_probability_max`. The current and hourly request still uses Unix timestamps.
- Daily units, array lengths, date order, duplicate dates, finite temperatures, minimum/maximum order and percentages are validated. Unknown weather codes have a neutral fallback.
- Missing values stay missing. They are never changed to zero or replaced with a later hour. Mismatched hourly arrays, duplicate times and percentages outside 0–100 are rejected.
- Missing search region or country is allowed. If a search result has no time zone, its model uses GMT as a fallback. Weather details use the time zone returned by the forecast request.
- HTTP errors are separate from data errors and offline failures. Timeouts and other connection failures are service errors. Cancellation is passed back without a user error. Server messages stay in the data layer.

The request contract follows the [Geocoding API documentation](https://open-meteo.com/en/docs/geocoding-api) and [Forecast API documentation](https://open-meteo.com/en/docs). Test responses are written from that contract; they are not recordings from the live service.
