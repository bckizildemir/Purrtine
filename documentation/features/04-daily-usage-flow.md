# Daily Usage Flow Documentation
**CatCareCalendar - Home dashboard and day-to-day interaction**

---

## Goal

The home experience should help a user understand today’s care workload in seconds, then act on it immediately.

---

## Home Surface

### Dashboard Priorities
- Show today’s task count.
- Show overdue or urgent work clearly.
- Show shortcuts into cats, history, and task creation.

### Quick Actions
- Support fast creation of common tasks or templated tasks.
- Keep the number of primary quick actions small and intentional.
- Route users into richer task screens when the task requires more configuration.

---

## Task Completion In Daily Use

- Today and urgent tasks should support fast completion paths.
- Shared or multi-cat completions may open a richer completion surface.
- Notification taps should return the user to the correct tab and relevant task state.
- Notification action flows must stay consistent with in-app completion flows.

---

## Technical Notes

- The home screen derives its state from current `CareTask`, `CareTaskSchedule`, and `CareTaskCompletion` data.
- Quick actions should create or route into the same task-creation flows used elsewhere rather than duplicating business logic.
- The baseline does not assume weather integration, AI personalization, or system-level activity prediction.
- If home metrics are expensive to compute, move aggregation out of `body`.

---

## UX And Accessibility

- The first screen should remain glanceable at large Dynamic Type sizes.
- Urgency should never rely on color alone.
- The user must always have at least one clear next action.
- Animations should be simple and optional under Reduce Motion.

---

## Future-State Notes

- More personalized dashboard ordering.
- Additional routine summaries or streak surfaces.
- Context-aware suggestions once the core reminder and completion loops are stable.
