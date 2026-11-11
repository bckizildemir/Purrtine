// Statechart view for OnboardingFinish.tla: the first-run flow as the caregiver sees it.
// Each chart state is a screen; arrows are what the caregiver does or what happens to the app.

const SCREEN = {
  welcome: "Welcome",
  permission: "Notifications",
  cat: "Your first cat",
  tasks: "Starter tasks",
};

export const title = "Purrtine first run: from Welcome to Home";

export const state = (v) => {
  const running = v.pre + v.post > 0;
  if (v.flag) {
    if (v.saved >= 2) return "Home with two first cats";
    if (v.saved === 1) return running ? "Home with the first cat, a save still running" : "Home with the first cat";
    return "Home with no cat";
  }
  // While a finish runs the caregiver may tap Back; the save goes on, so the chart shows one
  // "saving" state whatever screen is up.
  if (running) return "Saving your first cat";
  if (v.step === "tasks" && v.alert) return "Starter tasks: Couldn't save alert";
  const screen = SCREEN[v.step];
  if (v.saved >= 1) return `${screen}, a cat already saved`;
  return screen;
};

export const group = (v) => {
  if (v.flag) return "home";
  if (v.pre + v.post > 0 || v.alert) return "saving";
  return "onboarding";
};

export const colors = { onboarding: "blue", saving: "orange", home: "teal" };

const LABEL = {
  WelcomeContinue: "you tap Continue",
  AllowNotifications: "you allow notifications",
  DenyNotifications: "you don't allow notifications",
  SkipNotifications: "you skip notifications",
  PermissionChangedInSettings: "you change notifications in iOS Settings",
  CatContinue: "you name the cat and tap Continue",
  CatSkip: "you skip the cat",
  PickTask: "you tick a starter task",
  Back: "you tap Back",
  TapStart: "you tap Start",
  Retry: "you tap Try again",
  CommitSucceeds: "the cat and tasks are written",
  CommitFails: "the save fails",
  RemindersSynced: "reminders are set up",
  ContinueWithoutSaving: "you tap Continue without saving",
  KillAndRelaunch: "the app is killed and opened again",
  DeepLinkOrNotificationTap: "a link or notification opens the app",
  ResetOnboarding: "you reset onboarding (debug Settings)",
};

const isRunning = (v) => v.pre + v.post > 0;

// Hidden to keep the chart readable (every one of these is still checked by TLC):
// - Back on every screen: it only walks one screen back.
// - A kill on a screen with no save running: it only goes back to Welcome with nothing saved.
// - A failed save after you tapped Back during the save: you land on the screen you were on.
export const step = (action, from) => {
  if (action === "Back") return null;
  if (action === "KillAndRelaunch" && !isRunning(from) && !(from.alert && from.step === "tasks")) return null;
  if (action === "CommitFails" && from.step !== "tasks") return null;
  if (action === "CommitSucceeds" && !from.named) return "onboarding ends with no cat (name left empty)";
  return LABEL[action] ?? action;
};
