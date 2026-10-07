---
paths:
  - "CatCareCalendar/Views/**"
  - "CatCareCalendarUITests/**"
---

# Accessibility

- Every interactive control needs an accessible name (icon-only buttons still need a text label). Add accessibility values for dynamic state (completion %, reminder status, filters).
- Never communicate status via color alone. Respect Reduce Motion and Dynamic Type — adapt layout at large text sizes rather than clamping text.
- Mark decorative images hidden from accessibility; don't rely on raw SF Symbol names as the spoken label. Group a compound row/card's children when the combined reading is clearer than each subview separately.
- Maintain minimum 44x44pt touch targets; add explicit button traits when a custom tap target isn't a native control.
- Priority surfaces for accessibility verification: onboarding, task completion, notification actions, history.
