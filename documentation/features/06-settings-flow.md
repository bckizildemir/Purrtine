# Settings Flow Documentation
**CatCareCalendar - Preferences, support, and app controls**

---

## Goal

Settings should give users practical control over reminders, display preferences, shortcuts, and support surfaces without becoming a dumping ground for speculative features.

---

## Current Baseline

### More Tab Shell
- The app currently exposes settings through the More tab.
- The top-level surface should provide fast navigation into cats and history.

### Essentials
- Notification settings.
- Task display preferences such as default list vs. calendar mode.
- Haptic or display-related preferences backed by app settings.

### Information And Support
- About and legal information.
- Support and feedback routes.
- Developer tools in DEBUG builds only.

---

## Technical Notes

- Lightweight app preferences may use `@AppStorage` when the setting is truly simple and view-facing.
- More complex or shared settings should move into dedicated state or service layers rather than expanding `@AppStorage` indiscriminately.
- Notification controls should reflect actual `UserNotifications` capabilities and permission state.
- Debug tooling must remain clearly separated from production settings.
- The baseline does not assume email accounts, cloud accounts, export pipelines, or third-party integrations unless those features are explicitly added.

---

## UX And Accessibility

- Group settings by user intent, not by implementation detail.
- Explain the effect of important toggles, especially reminder-related ones.
- Keep destructive or debug actions clearly separated from normal preferences.
- Use standard iOS settings patterns for navigation, toggles, pickers, and disclosures.

---

## Future-State Notes

- Richer privacy and data-export controls.
- Cloud sync settings once sync exists.
- Broader caregiver and sharing preferences.
- Advanced appearance customization only if it has a clear product payoff.
