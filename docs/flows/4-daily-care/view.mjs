export const title = "Purrtine: daily care of one task";
export const state = (v) => {
  switch (v.screen) {
    case "home":
      if (v.occ === "waiting") return "Home, task not due yet";
      if (v.occ === "done") return "Home, done today, due tomorrow";
      return v.snoozed ? "Home, task due, reminder snoozed" : "Home, task due";
    case "banner": return "Reminder banner on screen";
    case "edit": return "Tasks tab with Edit Task sheet";
    case "tasks": return v.occ === "done" ? "Tasks list, task under Tomorrow" : "Tasks list, task due";
    case "whiskers": return v.occ === "due" ? "Whiskers, with the task chip" : "Whiskers, no chip";
    case "confirm": return "Whiskers chat, Confirm Completion card";
    case "chat": return v.occ === "done" ? "Whiskers chat, task is complete" : "Whiskers chat";
  }
};
export const group = (v) => (v.occ === "done" ? "Done" : v.occ === "due" ? "Due" : "Waiting");
export const colors = { Waiting: "blue", Due: "orange", Done: "teal" };
export const step = (a, f, t) => {
  switch (a) {
    case "TimeComes": return "the due time comes, a reminder shows";
    case "SnoozeFires": return "the snooze time comes";
    case "BannerGoesAway": return "you ignore it";
    case "BannerSnooze": return "you hold it and tap Remind in 10/30/60 min";
    case "BannerComplete": return "you hold it and tap Complete";
    case "BannerTap": return "you tap the reminder";
    case "CloseEdit": return "you tap Cancel";
    case "OpenTasks": return f.occ === "due" ? "you open the Tasks tab" : null;
    case "TasksToHome": return f.occ === "done" ? "you open the Home tab" : null;
    case "CompleteInList": return "you tap the circle (or swipe right, Complete)";
    case "OpenWhiskers": return f.occ === "due" && !f.snoozed ? "you open Whiskers" : null;
    case "WhiskersToHome": return f.screen === "chat" ? "you tap X, then Home" : null;
    case "TapChip": return "you tap the task chip";
    case "ConfirmCard": return "you tap Confirm";
    case "CancelCard": return "you tap Cancel";
    case "NextDay": return "the next day comes";
  }
};
