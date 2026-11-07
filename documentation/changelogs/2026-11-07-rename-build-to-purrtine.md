# 2026-11-07 — Build structure renamed from CatCareCalendar to Purrtine

The product has been called Purrtine for some time; the build structure now matches.

## Renamed

- Folders `CatCareCalendar/`, `CatCareCalendarTests/`, `CatCareCalendarUITests/` → `Purrtine/`,
  `PurrtineTests/`, `PurrtineUITests/`.
- `CatCareCalendar.xcodeproj` → `Purrtine.xcodeproj`; targets, products (`Purrtine.app`), the Swift
  module (`@testable import Purrtine`), shared schemes (`Purrtine`, `PurrtineTests`) and test plans
  (`Purrtine.xctestplan`, `PurrtineUnitTests.xctestplan`).
- `CatCareCalendarApp` → `PurrtineApp` (`Purrtine/PurrtineApp.swift`).
- CI (`.github/workflows/ci.yml`), `Scripts/check_coverage.sh`, the `verify-purrtine` and
  `testflight-release` skills, `.claude/rules/`, `CLAUDE.md`/`AGENTS.md`, `README.md`, `.gitignore`.
- `docs/legal/` synced with the live legal repository (product name Purrtine, new `privacy-tr/` page).

## Deliberately unchanged

Live or persisted identifiers keep the old name: bundle identifiers
`com.berkecankizildemir.CatCareCalendar*`, Logger subsystems, the preview UserDefaults suite, the
Firebase project id and functions package name, the URL scheme `catcarecalendar`, the legal site
`catcarecalendar-legal`, GitHub repository references, and dated history (changelogs, ADRs, audits).

SwiftData entity names are the bare class names, so an existing store opens unchanged:
`CatCareMigrationTests.realVersionOneStoreFixtureMigrates` passes after the rename.

## After pulling

- An untracked `GoogleService-Info.plist` stays in the old `CatCareCalendar/` folder; move it to
  `Purrtine/`.
- `Scripts/xcb.sh` keys its cache by project name, so the first build fills a new
  `~/Library/Caches/xcb/Purrtine/`; the old `CatCareCalendar` cache can be deleted.
