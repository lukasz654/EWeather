# AI contribution guide

## Start here

Read the [README](README.md), [architecture](docs/architecture.md) and [application behavior](docs/behavior.md) before changing the project. Inspect the relevant source and tests before relying on a description.

Keep recruitment requirements, user decisions and technical proposals distinct. Work within the requested scope and state uncertainty instead of inventing requirements or verification results.

## Project map

- `Packages/WeatherKit/Sources/WeatherDomain`: models, validation, errors and repository contracts.
- `Packages/WeatherKit/Sources/WeatherApplication`: use cases and application rules.
- `Packages/WeatherKit/Sources/WeatherData`: network and storage adapters, mapping and provider formats.
- `EWaeather/Presentation`: SwiftUI views, observable screen models, navigation and formatting.
- `EWaeather/App`: entry point and dependency composition.
- `Packages/WeatherKit/Tests` and `EWaeatherTests`: package and app tests.

## Implementation rules

- Follow Clean Architecture and SOLID. Keep responsibilities small and use protocol dependencies at module boundaries.
- Domain and Application must remain independent of SwiftUI, concrete storage and provider response types. Application and Data depend on Domain, not on each other.
- Presentation must not import WeatherData. Select concrete adapters in AppComposition.
- Use native SwiftUI controls, system colors and SF Symbols. Keep the interface in Polish and support Dark Mode and Dynamic Type.
- Put each View and each ViewModifier declaration in its own file.
- Preserve the distinction between missing values and zero. Respect the forecast city's time zone and date-only daily values.
- Keep sample providers and test helpers in test targets. Use controlled responses and isolated storage in tests.

## Validation

Run package tests when changing core rules or adapters:

```sh
swift test --package-path Packages/WeatherKit
```

Run app tests with the shared EWaeather scheme in Xcode using Product > Test when changing screen models or composition. For UI changes, check the affected flow, relevant loading and error states, Dark Mode and larger text on an iPhone simulator or device.

Choose checks that exercise the changed behavior. Report which checks actually ran and their limits in the conversation or review description. Source compilation alone does not verify runtime behavior.

## Documentation

- Write project documentation in clear English at B2 level.
- Keep the README focused on purpose, setup, features, architecture overview, test commands, product limitations and documentation links.
- Keep design explanations in docs/architecture.md and behavior or API decisions in docs/behavior.md. Link to existing explanations instead of copying them.
- Update documentation when the described behavior, setup or architecture changes.
- Keep test counts, per-revision pass reports and machine-specific execution notes out of project documentation. Keep local working notes outside version control.
- Do not publish personal recruitment notes, CV content, private messages or local document paths as project documentation.

## Git

Use small commits with one coherent purpose. Write commit messages in English at B2 level: a short one-sentence title without a final period, a blank line, then a brief description of the resulting behavior.

Preserve the full history and do not squash commits. Rewrite existing history only when the user explicitly requests it, preserving the metadata they ask to retain.
