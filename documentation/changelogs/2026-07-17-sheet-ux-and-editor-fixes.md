# Sheet UX & Editor Fixes — 2026-07-17

Branch: `bugfix/sheet-ux-and-editors`

## Overview
Batch of sheet/editor UX fixes: Reminders-style toolbar buttons, discard-changes
protection, cat form layout, a custom camera crop flow, task edit layout stability,
and task assistant keyboard/composer improvements.

## Changes

### 1. Reminders-style sheet toolbar buttons (X / ✓)
- New `Views/Components/SheetToolbarButtons.swift`: `SheetDismissButton` (X) and
  `SheetConfirmButton` (✓). On iOS 26 they use the new `Button(role: .close)` /
  `Button(role: .confirm)` system glyphs with Liquid Glass; on iOS 18 they fall back
  to hand-built circular buttons (gray X circle, blue filled checkmark).
- Adopted in: `CatFormView` (+ photo options sheet), `TaskAddView` (+ `FeedingDetailsSheet`),
  `TaskEditView`, `TaskAssistantView`, `TaskCompletionView`, `TaskCatsSelectionView`,
  `TaskTemplateSelectionView`, `CustomRepeatSheet`, `BulkTaskEditView`,
  `AddCaregiverView`, `CatDetailView.PhotoSheetView`, and the picker sheets in
  `TaskConfigurationComponents` (date/frequency/category/priority/reminder,
  cat & caregiver selection).

### 2. Discard-changes confirmation
- New `Views/Components/DiscardChangesConfirmationModifier.swift`
  (`.discardChangesConfirmation(isPresented:onDiscard:)`) with new localized keys
  `sheet.discard.title` / `sheet.discard.confirm` (en + tr).
- Form sheets track unsaved edits (snapshot on appear or model comparison) and show
  the dialog when X is tapped with pending changes. Swipe-to-dismiss is blocked while
  dirty via `.interactiveDismissDisabled(...)`.
- Applied to: cat add/edit form, task add/edit, feeding details, caregiver add,
  custom repeat, cat selection, task completion.

### 3. Edit cat sheet length
- Removed the fixed `Spacer().frame(height: 300)` under the delete button in
  `CatFormView`; keyboard avoidance is left to the system. Onboarding keeps its
  120pt footer spacing.

### 4–5. Camera capture & crop flow
- `CameraView` no longer uses `UIImagePickerController.allowsEditing` (its crop
  rectangle is broken/undraggable since iOS 13) and now exposes
  `onCapture`/`onCancel` callbacks; the picker view ignores safe areas inside the
  full screen cover so the preview fits small screens (iPhone 12 mini).
- New `Views/Components/CameraCaptureFlowView.swift` chains camera → crop.
- New `Views/Components/PhotoCropView.swift`: square "Move and Scale" cropper
  (drag + pinch, clamped so the image always covers the square) with
  Retake / Use Photo actions. New keys `photo.crop.title|retake|use` (en + tr).

### 6. Task edit sheet width jump
- Wheel `DatePicker`s (time pickers in `TaskAddView`/`TaskEditView`, interval wheel
  in `CustomRepeatSheet`) now use `.fixedSize()` before `.frame(maxWidth: .infinity)`.
  The wheel's intrinsic width was inflating the vertical `ScrollView`'s content
  width, visibly widening every section when the time section expanded.

### 7. Task assistant keyboard dismissal
- Message list now has `.scrollDismissesKeyboard(.interactively)` and
  `.dismissKeyboardOnTap()`.

### 8. Task assistant composer restyle
- Composer is now a Messages-style capsule: `glassEffect(.regular.interactive(), in: .capsule)`
  on iOS 26, material capsule with hairline border on iOS 18. Divider removed;
  mic/send accessory unchanged functionally.

## Localization
Added keys (en + tr, `extractionState: manual`): `sheet.discard.title`,
`sheet.discard.confirm`, `photo.crop.title`, `photo.crop.retake`, `photo.crop.use`.
