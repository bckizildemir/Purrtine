# Thumbnail Memory Downsampling — 2026-07-24

## Overview
Opening the Complete Task sheet for a task with more than one cat produced large memory
spikes (observed ~196 MB → ~262 MB in the Xcode memory gauge). The cause was full-resolution
image decoding: every place a cat/caregiver photo was shown at a small size used
`AsyncImage(url:)`, which decodes the entire stored bitmap into an uncompressed backing store.

Photos are saved as JPEGs compressed to ~1 MB of *file size* but with their original pixel
dimensions intact (e.g. 3024×4032). Decoding one to draw a 40×40 circle still allocates
`width × height × 4` bytes ≈ tens of MB. The multi-cat completion sheet decodes one per cat
row simultaneously, so the resident bitmaps stack up. `AsyncImage` also keeps no decoded-image
cache, so scrolling / re-rendering re-decodes.

## Changes Made

### New downsampling image pipeline
- `Utilities/DownsampledImageLoader.swift` — decodes files *downsampled* to a target pixel
  size via ImageIO (`CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize`),
  so a full-resolution bitmap is never materialized. Decoded thumbnails are held in a small
  `NSCache` keyed by path + pixel size. Decoding runs off the main actor.
- `Views/Components/DownsampledImage.swift` — a drop-in `AsyncImage(url:)` replacement for
  fixed-size photo displays. Takes the target point size, multiplies by `\.displayScale` to
  pick the decode resolution, fills the frame with `.aspectRatio(contentMode: .fill)`, and
  reloads via `.task(id:)` when the file or resolution changes.

### Swapped thumbnail sites (full-res `AsyncImage` → `DownsampledImage`)
- `Views/Tasks/TaskCompletionView.swift` — `MultipleCatSelectionRow` cat avatar (40 pt). This is
  the reported spike path.
- `Views/Tasks/TaskConfigurationComponents.swift` — `CatChip` (20 pt) and the cat selection row (40 pt).
- `Views/Cat/CatDetailView.swift` — header `avatarView` (140 pt); collapsed the duplicated
  path/URL `AsyncImage` branches into a single `catPhotoURL` helper.
- `Views/Cat/PhotoPickerSection.swift` — edit-mode photo circle (140 pt); added a `photoURL(for:)` helper.
- `Views/CaregiverManagementView.swift` — `CaregiverRowView` avatar (50 pt).

### Left intentionally unchanged
- The full-screen photo viewer in `CatDetailView` keeps `AsyncImage`: it is a single, on-demand,
  full-screen image using `.fit` (letterboxed), not part of the multi-image spike path.
- The full-resolution `selectedImages: [UIImage]` in the completion sheet: those are user-added
  proof photos, capped at 5 and only present after an explicit add — not the reported spike.

## Impact
Peak memory per thumbnail drops from ~tens of MB (full-res decode) to tens of KB (e.g. 40 pt @3x
= 120 px ≈ 57 KB). The completion sheet no longer scales its memory cost with the number of cats
that have photos.

## Verification
- `xcodebuild build` succeeds on iPhone 12 / iOS 26.5.
- Fresh-launch physical footprint measured at 61.4 MB (peak 64.0 MB) on the new build.
- Note: automated UI drive-through of the completion sheet could not be completed in this session
  because simulator input focus was not reaching the app instance (active user session / Instruments
  attached). The build-verified fix and decode math stand; recommend a confirming pass in Instruments
  by opening the 4-cat task's Complete Task sheet.
