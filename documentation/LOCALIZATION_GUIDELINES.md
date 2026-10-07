# Localization & Formatting Guidelines

These guidelines capture the rules for localized copy in CatCareCalendar following the July 2026 migration to a String Catalog.

---

## 1. Storage

- All user-facing strings live in the String Catalog `CatCareCalendar/Resources/Localizable.xcstrings`, covering English (`en`) and Turkish (`tr`).
- Keys are dot-separated (e.g. `tasks.header.today`) and use `extractionState: "manual"`.
- The build setting `STRING_CATALOG_GENERATE_SYMBOLS = YES` generates typed `LocalizedStringResource` symbols from the catalog at build time (`GeneratedStringSymbols_Localizable.swift`).
- The legacy per-locale `.strings`/`.stringsdict` files and the `localized` / `localized(with:)` String extensions were removed in this migration.

## 2. Access APIs

- SwiftUI text: `Text(.homeCurrentTasks)`.
- Plain strings: `String(localized: .tasksTitle)`.
- Parameterized keys generate typed functions with positional arguments:
  `String(localized: .taskAssistantOpenSuccess(task.title))`.
  `%d` placeholders map to `Int32` parameters — cast with `Int32(...)` when passing an `Int`.
- Do **not** call `String(format:)` or `NSLocalizedString` directly for compile-time-known strings.

## 3. Dynamic Keys (the one exception)

- `String.localizedDataKey` (`Utilities/LocalizationExtensions.swift`) resolves a localization key stored as *data*, where a compile-time symbol is impossible.
- The only current use is the persisted `Caregiver.localizationKey`; its canonical key constant is `CaregiverBootstrapper.defaultCaregiverLocalizationKey`.
- Do not introduce new dynamic-key call sites unless the key genuinely lives in data (persisted models, server responses).

## 4. Adding or Changing Keys

1. Add the key to `Localizable.xcstrings` with a `"translated"` value for **every** supported locale.
2. Keep placeholder counts, types, and positional order (`%1$@`, `%2$d`) consistent across locales.
3. Plural-sensitive strings use the catalog's `variations.plural` mechanism (example: `home.routine_status.days_ago`) — not separate singular/plural keys.
4. Build once so the symbol generates, then reference it.
5. Naming caution: symbol generation camelCases keys, so two keys that differ only in separators (`foo.some_key` vs `foo.someKey`) collide and fail the build.

## 5. Defensive Formatting

- Validate data before formatting user-visible strings.
- Return safe fallback strings for unknown or invalid values when that is the intended UX.

## 6. Validation Checklist

1. The key exists in the catalog with `"translated"` values for every supported locale.
2. Placeholder counts and types match across locales.
3. Access goes through generated symbols (or `localizedDataKey` for the persisted-caregiver case).
4. `LocalizationParityTests` passes (it validates the catalog: full translation coverage, consistent plural categories).
5. Edge cases render fallback copy.
6. The affected UI is checked in English and Turkish.
7. Tests are added or updated when formatting logic changes materially.
