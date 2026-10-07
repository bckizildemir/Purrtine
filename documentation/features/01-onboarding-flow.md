# Onboarding Flow Documentation
**CatCareCalendar - First-run setup**

---

## Goal

Get a new user from first launch to a usable dashboard quickly, while collecting only the information needed to create immediate value.

### Success Criteria
- Reach the dashboard in under 90 seconds.
- Ask for only one required data field during first-cat setup: cat name.
- Explain notification value before showing the system permission prompt.

---

## Core Flow

### 1. Welcome
- Introduce the app’s value clearly and briefly.
- Show one primary action to continue.
- Avoid long feature lists or setup anxiety on the first screen.

### 2. Notification Permission
- Explain why reminders matter before requesting system permission.
- Allow the user to continue even if they skip or deny permission.
- Do not stack unrelated permission prompts during onboarding.

### 3. First Cat Setup
- Required: cat name.
- Optional: photo, age, breed, gender, notes, and similar profile details.
- Keep optional details lightweight and skippable.

### 4. Starter Task Setup
- Offer common starter tasks such as feeding, medication, litter, and grooming.
- Make it easy to skip this step and create tasks later.
- Preselected choices should be conservative and easy to edit later.

### 5. Completion
- Confirm that setup is finished.
- Transition directly into the main app experience.
- Avoid a dead-end success screen.

---

## Technical Notes

- The onboarding flow stores temporary state until completion, then creates the real SwiftData records.
- Completing onboarding may create:
  - one `Cat`
  - zero or more `CareTask` records
  - matching `CareTaskSchedule` records for selected starter tasks
- The app should assign the default caregiver if the local model requires one.
- Notification authorization must never block core app usage.

---

## UX And Accessibility

- Use semantic text styles and adaptive spacing.
- Keep transitions simple and respectful of Reduce Motion.
- Ensure the back path is clear for multi-step onboarding.
- VoiceOver labels must describe the purpose of each action, especially photo and permission controls.

---

## Future-State Notes

- Returning-user restoration across devices.
- Optional caregiver setup during onboarding.
- More personalized task recommendations after the core flow is stable.
