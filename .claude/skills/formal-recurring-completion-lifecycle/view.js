// /statechart view for RecurringCompletion.tla: the words a Purrtine caregiver reads.
// A TLA+ sequence arrives as an object keyed from 1; a set arrives as an array.

const seq = (s) => Object.values(s ?? {});

const activeDay = (v) => {
  const days = seq(v.scheds).filter((s) => s.active).map((s) => s.day);
  return days.length ? Math.min(...days) : null;
};

const doneText = (v) => {
  const days = seq(v.done).map((d) => d.for);
  return days.length ? `done: day ${days.join(", day ")}` : "nothing done yet";
};

export const title = "One daily care task as caregivers complete it";

export const state = (v) => {
  if (!v.exists) return "Task deleted";
  if (v.status === "completed") return `Task closed (${doneText(v)})`;
  const due = activeDay(v);
  if (due === null) return `Open with no active schedule, today is day ${v.today} (${doneText(v)})`;
  return `Due day ${due}, today is day ${v.today} (${doneText(v)})`;
};

export const group = (v) => (!v.exists ? "gone" : v.status === "completed" ? "closed" : "open");

export const colors = { open: "blue", closed: "teal", gone: "tan" };

const sourceWords = {
  sheet: "the task list's Complete (row or sheet)",
  calendar: "the calendar's Complete",
  assistant: "Whiskers' confirmation",
  notification: "Complete on the reminder",
};

const committed = (from, to) => {
  for (const s of Object.keys(sourceWords)) {
    if (from.req[s].seen !== -1 && to.req[s].seen === -1) return s;
  }
  return null;
};

export const step = (action, from, to) => {
  switch (action) {
    case "DayPasses":
      return "a new day begins";
    case "TapCompleteInList":
      return `a caregiver taps Complete in the task list for day ${to.req.sheet.seen}`;
    case "TapCompleteInCalendar":
      return `a caregiver picks day ${to.req.calendar.seen} in the calendar and taps Complete`;
    case "AskWhiskersToComplete": {
      const r = to.req.assistant;
      return r.forDate === -1
        ? "a caregiver asks Whiskers to complete the task; Whiskers asks to confirm"
        : `a caregiver tells Whiskers it was done on day ${r.forDate}; Whiskers asks to confirm`;
    }
    case "ReminderFires":
      return `the reminder for day ${to.req.notification.seen} arrives`;
    case "CompletionSaved": {
      const s = committed(from, to) ?? "sheet";
      const last = seq(to.done).at(-1);
      return `${sourceWords[s]} saves a completion for day ${last.for}`;
    }
    case "CompletionSaveFails":
      return "the save fails and the completion is undone";
    case "CompletionFindsNoTask":
      return "a pending completion finds the task gone";
    case "DeliveredRemindersRemoved":
      return "the app clears the task's delivered reminders";
    case "OpenEditForm":
      return `a caregiver opens Edit Task (date shows day ${to.form})`;
    case "SaveEditForm":
      return "the caregiver saves Edit Task";
    case "CloseEditForm":
      return "the caregiver closes Edit Task";
    case "DeleteTask":
      return "a caregiver deletes the task (or its only cat)";
    case "DeleteCat":
      return to.exists ? "a caregiver deletes one of the task's two cats" : "a caregiver deletes the task (or its only cat)";
    case "Gone":
      return null;
    default:
      return action;
  }
};
