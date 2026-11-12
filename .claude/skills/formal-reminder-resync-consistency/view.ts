// Statechart view for ReminderResync.tla: the caregiver's words for states and steps.
// Read by the /statechart skill with --view. Each function depends only on its arguments.

type Vars = Record<string, any>;

const snoozes = (v: Vars): any[] => (v.pending ?? []).filter((r: any) => r.kind === "snooze");

const busy = (v: Vars): boolean =>
  v.passPc !== "idle" || v.queued === true || v.act.app.pc !== "idle" || v.act.notif.pc !== "idle";

const finished = (v: Vars, task: number, occ: number): boolean =>
  !v.alive[task] || v.staged[task] || v.occ[task] !== occ;

// One label per thing the caregiver could notice: what is still in flight, whether reminders are
// on, and what the pending snoozes are worth.
export const state = (v: Vars): string => {
  const on = v.settingsOn && v.perm === "on";
  const inFlight: string[] = [];
  if (v.passPc !== "idle" || v.queued) inFlight.push("resync running");
  const n = v.act.notif;
  if (n.pc === "sz_fetch") inFlight.push("snooze tapped");
  if (n.pc === "sz_add") inFlight.push(finished(v, n.task, n.occ) ? "snooze on its way for a finished task" : "snooze on its way");
  if (v.act.app.pc !== "idle") inFlight.push("clearing the task's snoozes");
  if (n.pc === "cs_read" || n.pc === "cs_remove") inFlight.push("clearing the task's snoozes");
  const s = snoozes(v);
  const stale = s.some((r: any) => finished(v, r.task, r.occ));
  const parts: string[] = [inFlight.length ? inFlight.join(" + ") : "Settled"];
  parts.push(on ? "reminders on" : v.perm === "unknown" ? "permission not read yet" : "reminders off");
  if (s.length === 0) parts.push("no snooze");
  else if (stale) parts.push("a snooze for a finished or deleted task");
  else parts.push(s.length > 1 ? `${s.length} snoozes` : "1 snooze");
  return parts.join(", ");
};

export const group = (v: Vars): string => (busy(v) ? "settling" : "settled");

export const colors = { settling: "orange", settled: "blue" };

export const title = "Care-task reminders: resync, snooze, complete, delete";

const verbs: Record<string, string> = {
  PassFetch: "the resync reads the saved tasks",
  PassAuth: "the resync reads the permission",
  PassRead: "the resync reads the pending reminders",
  PassApply: "the resync removes stale reminders",
  PassAdd: "the resync adds a reminder",
  CancelSnoozesRead: "the app looks up the task's snoozes",
  CancelSnoozesRemove: "the app removes the task's snoozes",
  EditSchedule: "you edit a task's schedule",
  DeleteCat: "you delete the cat",
  ToggleSettings: "you switch reminders in Settings",
  ChangePermission: "you change notification permission in iOS Settings",
  LaunchPermissionCheck: "the app launches and reads the permission",
  AppActivation: "you open the app",
  SnoozeTap: "you tap Remind me on a reminder",
  SnoozeFetch: "the snooze looks up the task",
  SnoozeAdd: "the snooze is scheduled",
  Done: "nothing more happens",
};

export const step = (action: string, from: Vars, to: Vars): string | null => {
  if (action === "Done") return null;
  if (action === "Complete") return to.act.notif.pc !== from.act.notif.pc ? "you tap Complete on a reminder" : "you complete a task in the app";
  if (action === "DeleteTask") return to.staged && Object.values(to.staged).some(Boolean) && !Object.values(from.staged).some(Boolean)
    ? "you delete a task [the save fails]"
    : "you delete a task";
  if (action === "PassFetch" && to.lastPass === "failed") return "the resync cannot read the saved tasks";
  if (action === "PassAdd" && to.passPc === "idle") return "the resync finishes";
  return verbs[action] ?? action;
};
