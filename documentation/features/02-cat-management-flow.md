# Cat Management Flow Documentation
**CatCareCalendar - Cat profiles and multi-cat organization**

---

## Goal

Let users add, review, edit, and organize cat profiles without turning profile management into a heavy administrative task.

---

## Entry Points

- More tab shortcut to My Cats.
- Home dashboard shortcuts.
- Task creation and task assignment flows.
- Empty states when no cat profiles exist.

---

## Core Flow

### Cat Gallery
- Show all cats in an iPhone-friendly responsive layout.
- Prioritize recognition by name and photo.
- Support empty, single-cat, and multi-cat states cleanly.

### Add Cat
- Require only the cat name.
- Support optional profile fields such as age, gender, breed, weight, notes, medical conditions, and photo.
- Make photo selection optional and non-blocking.

### Cat Detail
- Show profile details, recent task context, and quick actions such as edit, add task, or view related history.
- Destructive actions must require confirmation.

### Edit Cat
- Reuse the same data model as add-cat where possible.
- Preserve existing photos and profile details unless the user changes them.

---

## Data And Technical Notes

- Cat data is stored in SwiftData using the `Cat` model.
- The current model supports:
  - `name`
  - `photoURLs`
  - `age` in months
  - `gender`
  - `breed`
  - `weight` and `weightUnit`
  - `medicalNotes`
  - `medicalConditions`
- Cat-to-task relationships must preserve shared-task behavior correctly when a cat is edited or removed.
- Photo handling should remain local-first and go through the app’s photo utilities instead of ad-hoc file writes.

---

## UX And Accessibility

- Search and filtering should appear only when the list size justifies them.
- The layout must scale to larger Dynamic Type sizes.
- Do not rely on photo presence to make the experience understandable.
- VoiceOver labels should make cat cards and actions self-explanatory.

---

## Future-State Notes

- Richer health records.
- Shareable profile exports.
- Broader caregiver collaboration around a single cat profile.
