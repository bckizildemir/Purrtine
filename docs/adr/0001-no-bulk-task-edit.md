---
status: accepted
date: 2026-09-08
---

# No bulk task edit

CatCareCalendar will not ship a bulk task edit feature. `BulkTaskEditView` was built but never
wired into any navigation path — only its own Xcode preview constructed it — and the architecture
review of 31 July 2026 flagged the choice between wiring it up and deleting it as an open product
call (CatCareCalendar#16,
CatCareCalendar#15). The product direction is that
care tasks are edited one at a time, so the screen is deleted rather than finished.

## Consequences

- Three files are removed: `Views/Tasks/BulkTaskEditView.swift`,
  `Utilities/BulkTaskEditService.swift`, and `CatCareCalendarTests/Utilities/BulkTaskEditServiceTests.swift`.
- Issue CatCareCalendar#12 ("Bulk task edit reconciles
  reminders") landed a real fix inside `BulkTaskEditService`. That fix is deleted along with the
  feature. The defect it closed is no longer reachable, because the code path no longer exists.
- The care-task mutation seam (CatCareCalendar#16)
  covers one fewer call site. Multi-task reminder resync is still required for the cat-delete and
  cat-rename paths, so the seam still needs a plural operation.
- Do not re-propose bulk editing as a fix for reminder-consistency or task-management friction. If
  the product direction changes, supersede this ADR rather than reviving the deleted screen.
