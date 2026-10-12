# 2026-10-12 — Cat photo: a menu replaces the photo-source sheet

Tapping the photo on the cat form opened a sheet with large Camera and Gallery buttons (a glass
two-chip sheet in onboarding, a medium-detent sheet in Add Cat and Edit Cat). It now opens the
system menu, the same control iOS uses for a photo-source choice.

## What changed

- **One menu on every cat form.** `PhotoPickerSection` wraps the photo circle and its label in a
  `Menu`: Camera, Photo Library, and Remove Photo (only when a photo exists). Onboarding, Add Cat and
  Edit Cat all use it. The Camera row is hidden on a device without a camera, the same as the task
  completion photo dialog.
- **Library through `photosPicker(isPresented:)`.** Photo Library sets
  `CatFormData.isShowingPhotoLibrary`, and `CatFormView` presents the system picker. The retry
  message's "choose another" opens the library directly.
- **Remove shows at once in Edit Cat.** Removing a stored photo used to leave it on screen until
  Save. The photo circle, the label and the menu now drop it immediately.
- **VoiceOver.** The menu reads "Add Photo" or "Edit Photo" instead of the symbol names.
- **"Photo Library".** The key `cat.add.photo_gallery` is now `cat.add.photo_library`: en
  "Photo Library", tr "Fotoğraf Arşivi" (the iOS system names). The task completion photo dialog
  shares the key, so its wording changes too.

The old sheet code (`photoOptionsSheet`, `OnboardingPhotoActionLabel`) is deleted.
`2026-07-17-sheet-ux-and-editor-fixes.md` describes the sheet as it was.
