# Pre-Publish Audit Fixes — 2026-07-20

## Overview
A comprehensive pre-publish scan surfaced dead-end flows and App Store readiness gaps. This change fixes the confirmed issues.

## Changes Made

### Legal & support links now live (`SettingsSupportConfiguration.swift`)
- Privacy Policy / Terms of Service previously pointed at `catcarecalendar.app` (unregistered domain, dead links). Pages are now hosted on GitHub Pages: <https://bckizildemir.github.io/catcarecalendar-legal/privacy/> and <https://bckizildemir.github.io/catcarecalendar-legal/terms/> (public repo `bckizildemir/catcarecalendar-legal`; local source copies in `docs/legal/`).
- "Give Feedback" fallback email changed from the nonexistent `support@catcarecalendar.com` to `bcankizildemir@gmail.com`. The `SUPPORT_EMAIL` Info.plist override hook is unchanged.
- "Rate App" still hidden until `APP_STORE_ID` is set (do this after the first App Store Connect listing exists).

### Cat-card "Add Task" wired to the real form
- The context-menu "Add Task" on cat cards previously opened a placeholder sheet showing only text (`// TODO: TaskAddView for specific cat`). It now presents `TaskAddView` with the cat preselected.
- `TaskAddView` gained an optional `preselectedCat:` init parameter (backward compatible with all existing call sites).
- Removed the dead swipe-gesture/quick-actions code in `EnhancedCatCardView.swift` (commented-out gesture, unreachable `quickActionsOverlay`, drag handlers, orphaned state).
- Removed now-unused catalog keys `cat.card.add_task` and `cat.card.add_task_placeholder`, plus a stray empty-string key that broke `LocalizationParityTests`.

### Release hygiene
- `HomePageView.logStats()` debug output is now `#if DEBUG`-guarded (previously printed in release builds).
- `PhotoManager.deletePhoto(at:)` / `deleteAllPhotos(for:)` no longer swallow errors silently; failures are logged.

## Verification
- Full unit suite green on iPhone 12 / iOS 18.5 (including `LocalizationParityTests`).
- `CriticalFlowsUITests` run sequentially on iOS 18.5 and 26.5.
- Both GitHub Pages URLs verified returning HTTP 200.
