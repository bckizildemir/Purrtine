# Photo Downscale-on-Save + Thumbnail Migration (Perf Batch 1) — 2026-07-24

First execution batch from `documentation/performance-improvement-plan.md`
(items P0.1, P0.2, P1.8). Follows the thumbnail-downsampling memory fix from earlier the same day.

## Overview
The earlier fix stopped the *display* side from decoding full-resolution photos. This batch fixes the
*source*: photos were still **saved** at their original pixel dimensions (a quality-only JPEG loop that
never resized), so every stored image was expensive by construction. It also finishes migrating the
remaining full-res thumbnail sites and moves photo saving off the main actor.

## Changes

### P0.1 — Downscale photos on save
- `Utilities/DownsampledImageLoader.swift`: extracted a shared `downsampledCGImage(from:maxPixelSize:)`
  that also accepts in-memory `Data` (previously URL-only), reused by both display loading and saving.
- `Utilities/PhotoManager.swift`: added `downsampledJPEGData(from:maxPixelSize:compressionQuality:)`
  (Data and UIImage overloads) — downsamples via ImageIO then encodes JPEG **once**. Added
  `photoMaxPixelSize = 2048` / `avatarMaxPixelSize = 512` caps. `savePhoto`/`saveUIImage` now route
  through it (shared `writeJPEG`), and the old quality-only `compressImage` loop was deleted.
- Routed the three duplicated save paths through the shared encoder and deleted their private
  `compressImage` copies: `Models/TaskManagementViewModel.swift`, `Models/TaskAssistantViewModel.swift`
  (task photos, 2048), `Views/AddCaregiverView.swift` (avatar, 512).
- Result: a 3024×4032 camera photo is stored at ≤2048px instead of full-res — smaller files **and**
  cheap decodes everywhere downstream. Onboarding (`OnboardingDataBuilder`) and `CatFormView` already
  route through `PhotoManager`, so they inherit the cap.

### P0.2 — Finish the DownsampledImage migration
Swapped the last full-res `AsyncImage` thumbnail sites to `DownsampledImage`:
- `Views/Cat/EnhancedCatCardView.swift` — the My Cats grid card (highest impact: a scrolling
  collection of cards). Added a `catPhotoURL` helper mirroring `CatDetailView`.
- `Views/Tasks/TaskConfigurationComponents.swift` — `CaregiverSelectionRow` 40-pt avatar.
- `Views/Cat/CatFormView.swift` — the picked-photo preview is now bounded because the picked image is
  downsampled at ingestion (see P1.8); the form no longer holds/persists a full-res original.

### P1.8 — Photo save off the main actor
- `Views/Cat/CatFormView.swift`: `saveNewCat`/`saveExistingCat` are now `async`; the decode/encode/disk
  write runs in `Task.detached` via a `savePhotoOffMainActor(for:)` helper, keeping only SwiftData
  mutations on the main actor. `loadSelectedPhoto` downsamples the picked `Data` off the main actor at
  ingestion. Removes the Save-button main-thread hang on large photos.

## Verification
- `xcodebuildmcp` `build_sim` / `build_run_sim` succeed on iPhone 12 / iOS 26.5, **zero warnings**.
- App launches clean; Home footprint 79.2 MB.
- Runtime memory of the My Cats grid and the no-hang Save flow to be confirmed interactively (the
  active xcodebuildmcp profile is observe-only — no tap automation).

## Notes / follow-ups
- `PhotoManager.generateThumbnail` and `loadPhoto` remain unused (flagged for deletion in plan P2.12);
  left untouched in this batch.
- Existing photos saved before this change keep their original dimensions; only new saves are capped.
  A one-time re-compress migration could be added later if desired.
