# App-Wide Dark/Light Mode — 2026-07-17

## Summary

The app previously forced dark mode via a hardcoded `.preferredColorScheme(.dark)` at the
root, and the UI was styled for a dark canvas only. This change introduces a user-facing
appearance preference (System / Light / Dark) and makes every screen adaptive.

## Changes

### Appearance preference
- New `AppearanceMode` enum (`Models/AppearanceMode.swift`): `system` / `light` / `dark`,
  mapping to `preferredColorScheme` (`nil` for system).
- New `appearance_mode` UserDefaults key and `resolvedAppearanceMode(from:)` resolver in
  `SettingsPreferences` (falls back to `.system` for missing/unknown values).
- `CatCareCalendarApp` drives `preferredColorScheme` from the stored preference instead of
  hardcoding `.dark`. **Default is System** — users whose device is in light mode now get a
  light app instead of the previously forced dark appearance.
- New "Appearance" segmented picker section in Settings (More tab), localized in en + tr
  (`settings.appearance.*` keys).

### Adaptive color sweep (~25 view files)
- Literal `.white` text/icons on adaptive backgrounds → `.primary`; dimmed white → `.secondary`.
- `.gray` secondary text → `.secondary` / `.tertiary` (preserving hierarchy).
- Dark-tuned translucent fills (`Color.gray.opacity(...)`, `Color.white.opacity(...)`) →
  `Color(.systemFill)` / `Color(.secondarySystemBackground)`.
- Forced `Color.black` backgrounds in onboarding and bulk task edit → `Theme.background`.
  Camera capture and photo-crop screens intentionally remain black.
- White kept only on solid colored fills (buttons, badges, category chips, photo scrims).
- Deleted `Utilities/ColorScheme.swift` (fixed dark-only hex palette); its two live uses in
  `TaskAssistantView` migrated to semantic system colors.
- Bug fix: calendar week cell used `isSelected ? .white : .white` (always white).
- `SheetConfirmButton` disabled state now uses `secondaryLabel` on `systemGray4` for adequate
  light-mode contrast.

### Sheet dismiss / discard-changes refactor
- `SheetDismissButton` gained an `init(hasUnsavedChanges:onDismiss:)` that owns the
  "Discard Changes" confirmation dialog internally, anchored to the button.
- Removed `DiscardChangesConfirmationModifier` and the per-view `showingDiscardConfirmation`
  state from TaskAdd/TaskEdit/CustomRepeatSheet/TaskCatsSelection and related sheets.
- Minor editor polish in `TaskAddView` (notes field uses body font with a minimum height).

### Tests
- `SettingsPreferencesTests`: appearance resolver fallback cases + color-scheme mapping.
- `LocalizationParityTests` fixed: removed a stray empty `""` key from `Localizable.xcstrings`
  that pre-dated this branch.
- `CriticalFlowsUITests`: the snooze-notification test now scrolls to the developer-tools row,
  which the new Appearance section pushed below the fold.

## Verification
- Build + 115/115 unit tests (iPhone 12, iOS 18.5).
- UI suite: 24/24 on iOS 26.5; 18.5 pass with one unrelated flake (passes standalone).
- Visual light/dark screenshots of Home; end-to-end check that `appearance_mode = light`
  overrides a dark system setting at launch.
