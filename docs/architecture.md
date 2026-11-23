# Architecture and design decisions

The app follows Clean Architecture with MVVM in the presentation layer. One local Swift package, `Packages/WeatherKit`, contains three library modules. The Xcode app target keeps the interface and dependency composition.

See the [dependency diagram](../README.md#architecture) in the README.

| Module or app area | Responsibility | Project dependencies |
| --- | --- | --- |
| `WeatherDomain` | City and weather models, local calendar days, conditions, city name validation, errors, and small repository contracts | None |
| `WeatherApplication` | Search, hourly and three-day forecast use cases, plus history order and duplicate rules | `WeatherDomain` |
| `WeatherData` | URLSession transport, HTTP errors, Open-Meteo requests, response mapping and UserDefaults history storage | `WeatherDomain` |
| `EWaeather/Presentation` | SwiftUI views, observable screen models, navigation and display formatting | `WeatherApplication`, `WeatherDomain` |
| `EWaeather/App` | Entry point and dependency composition | All three modules |

An arrow means a source code dependency, not the order of runtime calls. SwiftPM declares the dependencies between the three library modules. Domain and Application do not depend on SwiftUI, URLSession, UserDefaults or provider response types. Application and Data do not depend on each other.

Presentation and composition share one app target. Their boundary is checked in code review: presentation files do not import WeatherData. `AppComposition` creates the live adapters and injects them through domain contracts into use cases, then into screen models. A runtime call can reach a Data adapter through a domain protocol without Application importing Data.

WeatherData exposes the live repository and history storage implementations, plus a transport contract for injection. HTTP handling, request construction, response types, mapping and the stored JSON format stay internal or private. Sample repositories and in-memory history used by tests stay in the test target; they do not become part of the package API.

This split supports SOLID through concrete responsibilities:

- **Single responsibility:** screen models manage presentation state, use cases manage app rules, and adapters handle external data formats and storage.
- **Open/closed:** a different provider can implement the existing contracts and be selected in composition without changing the use cases or screen models.
- **Liskov substitution:** tests check missing results, errors and cancellation, including providers that ignore cancellation. Matching protocol signatures alone is not enough.
- **Interface segregation:** city search, weather loading, history reading and history writing have separate contracts.
- **Dependency inversion:** Application and Data depend on contracts owned by Domain. Concrete adapters are selected in composition.

One local package keeps setup simple while making the core dependencies explicit. Search and forecast remain separate feature folders in the app. There are no additional UI or feature modules for these two screens.

## Dependency composition

The [package manifest](../Packages/WeatherKit/Package.swift) declares library and test dependencies. [AppComposition](../EWaeather/App/AppComposition.swift) is the place where concrete data adapters are selected.

UserDefaults belongs to the local history adapter. Use cases depend on the history reading and writing protocols, so changing the storage implementation does not require a change to the application rules.

## Testing boundaries

Package tests do not import the app. Domain and Application tests do not import WeatherData or use real network or storage implementations. App integration tests use the public data API with controlled HTTP responses. The app and data test targets each keep their own small transport stub so test helpers are not exposed as a library product.
