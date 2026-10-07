# String Catalog & Modern API Migration — 2026-07-12

Two coordinated modernization passes aligning the codebase with the Paul Hudson agent guide adopted in `CLAUDE.md`/`AGENTS.md`.

## Part A — Localization: `.strings`/`.lproj` → `Localizable.xcstrings`

### Storage
- Converted `Resources/en.lproj` + `Resources/tr.lproj` (`Localizable.strings` + `Localizable.stringsdict`, 951 keys per locale, 3 plural keys) into a single String Catalog `Resources/Localizable.xcstrings`. Round-trip verified: `xcstringstool compile` output matched the original files key-for-key in both locales before the swap.
- Enabled `STRING_CATALOG_GENERATE_SYMBOLS = YES` (app target, Debug + Release); the build now generates typed `LocalizedStringResource` symbols.
- Removed 12 dead snake_case duplicate keys (0 code references each) whose camelCase twins collided under symbol generation (e.g. `calendar.completed_tasks` vs live `calendar.completedTasks`).
- Added 2 previously missing accessibility keys surfaced by the migration (`cat.add.age_hint`, `cat.add.age_unit_label` — VoiceOver had been reading raw key strings).

### Call sites (~815 across ~60 files)
- `"key".localized` / `LocalizedKey.member.localized(with:)` → generated symbols: `Text(.homeCurrentTasks)`, `String(localized: .taskAssistantOpenSuccess(task.title))`. `%d` placeholders map to `Int32` parameters.
- `CareTaskTemplate`/`CareTaskTime`/`CareTaskCustomField` key fields retyped `String` → `LocalizedStringResource` (with manual `Hashable` conformances — `LocalizedStringResource` is `Equatable` but not `Hashable`).
- `NotificationSettingsPresentation` key fields retyped to `LocalizedStringResource`; tests assert via `.key`.
- Persisted `Caregiver.localizationKey` keeps a raw key string (it is data): resolved via the new narrow `String.localizedDataKey` helper; canonical constant `CaregiverBootstrapper.defaultCaregiverLocalizationKey`.
- Deleted the legacy API: `String.localized` / `localized(with:)`, the 590-constant `LocalizedKey` struct, `LocalizedText`, `Text(localized:)`, `accessibilityLocalized`, and the DEBUG placeholder inspector.
- `LocalizationParityTests` rewritten to validate the catalog directly (full translation coverage per locale, consistent plural categories).

## Part B — Legacy `Formatter`/GCD removal

- Replaced all 21 `DateFormatter` call sites (10 files) with `FormatStyle` (`date.formatted(...)`, `Date.FormatStyle`, `.verbatim` templates). The app target now has zero `DateFormatter`/`NumberFormatter`/`MeasurementFormatter` usage.
- Fixed the `HomeRoutineStatusPresentation`/`HomeRoutineStatusRowView` string→Date→string round-trip by passing the completion `Date` through the presentation row instead of re-parsing display text.
- Replaced all 7 `DispatchQueue` call sites (6 files) with structured concurrency (`Task`, `Task.sleep(for:)`, `@MainActor`); callback-based system APIs (camera, speech, notification permission) bridged with `withCheckedContinuation`.

## Verification

- Full unit suite: 92 tests in 25 suites, all passing.
- UI smoke tests passed post-migration: onboarding happy path, task create/complete, notification snooze (an initial full-suite failure of the snooze test re-ran green in isolation — flaky, ~2h suite run).
- Docs updated: `CLAUDE.md`, `AGENTS.md` (reconciliation notes flipped to "in force"), `.cursor/rules/localization.mdc`, `documentation/LOCALIZATION_GUIDELINES.md`.
