---------------------------- MODULE OnboardingFinish ----------------------------
(***************************************************************************)
(* The first-run flow of Purrtine, from Welcome to Home, and the finish   *)
(* step that saves the first cat and its starter tasks.                    *)
(*                                                                         *)
(* Every action names the code it stands for. One action = one stretch of *)
(* main-actor code with no `await` in it, so TLC may put any other action *)
(* (a second tap, a kill, a Settings change) between two actions.         *)
(*                                                                         *)
(* The three constants are read from the code by run.sh (see SKILL.md):   *)
(* each is TRUE when its guard is still in the code, FALSE when it is     *)
(* gone, so the model checks the code as it is.                           *)
(***************************************************************************)
EXTENDS Naturals

CONSTANTS
  FinishGuard,        \* OnboardingTaskSetupModel.finish: `guard isFinishing == false`
  UnstageOnFail,      \* OnboardingDataBuilder: `unstage(...)` after a failed first commit
  FlagOnlyAfterSave   \* OnboardingTaskSetupModel.finish: completeOnboarding only when outcome != .notSaved

VARIABLES
  flag,        \* OnboardingManager.hasCompletedOnboarding (UserDefaults: survives a kill)
  step,        \* OnboardingManager.currentStep / OnboardingView.currentStep (memory only)
  named,       \* tempCatData.name is not empty (memory only)
  picked,      \* selectedTasks is not empty (memory only)
  pre,         \* finish() calls running that have not reached the commit yet
  post,        \* finish() calls whose commit is done, awaiting the reminder resync
  staged,      \* cats inserted in the ModelContext but not committed (memory only)
  saved,       \* cats onboarding committed to the store since the last resetOnboarding
  alert,       \* OnboardingTaskSetupModel.isShowingSaveFailure
  noCatChosen, \* the caregiver chose to end onboarding without a cat (empty name, or
               \* "Continue without saving")
  perm         \* notification authorization: "notAsked", "allowed", "denied"

vars == <<flag, step, named, picked, pre, post, staged, saved, alert, noCatChosen, perm>>

Running == pre + post
InOnboarding == flag = FALSE           \* ContentView shows OnboardingView

Init ==
  /\ flag = FALSE /\ step = "welcome" /\ named = FALSE /\ picked = FALSE
  /\ pre = 0 /\ post = 0 /\ staged = 0 /\ saved = 0 /\ alert = FALSE
  /\ noCatChosen = FALSE /\ perm = "notAsked"

Keep(v) == UNCHANGED v

\* ---- Welcome, permission, first cat (OnboardingView step closures) ----

WelcomeContinue ==        \* WelcomeView onContinue
  /\ InOnboarding /\ step = "welcome"
  /\ step' = "permission"
  /\ Keep(<<flag, named, picked, pre, post, staged, saved, alert, noCatChosen, perm>>)

AllowNotifications ==     \* NotificationPermissionView: requestPermission, then onContinue
  /\ InOnboarding /\ step = "permission"
  /\ perm' = IF perm = "notAsked" THEN "allowed" ELSE perm
  /\ step' = "cat"
  /\ Keep(<<flag, named, picked, pre, post, staged, saved, alert, noCatChosen>>)

DenyNotifications ==      \* the system prompt answered "Don't Allow"; onContinue still runs
  /\ InOnboarding /\ step = "permission" /\ perm = "notAsked"
  /\ perm' = "denied"
  /\ step' = "cat"
  /\ Keep(<<flag, named, picked, pre, post, staged, saved, alert, noCatChosen>>)

SkipNotifications ==      \* NotificationPermissionView onSkip
  /\ InOnboarding /\ step = "permission"
  /\ step' = "cat"
  /\ Keep(<<flag, named, picked, pre, post, staged, saved, alert, noCatChosen, perm>>)

PermissionChangedInSettings ==  \* iOS Settings toggle; read live by reminderPrompt
  /\ perm # "notAsked"
  /\ perm' = IF perm = "allowed" THEN "denied" ELSE "allowed"
  /\ Keep(<<flag, step, named, picked, pre, post, staged, saved, alert, noCatChosen>>)

CatContinue ==            \* CatFormView .onboarding saveCat: name into tempCatData, onContinue
  /\ InOnboarding /\ step = "cat"
  /\ named' = TRUE /\ step' = "tasks"
  /\ Keep(<<flag, picked, pre, post, staged, saved, alert, noCatChosen, perm>>)

CatSkip ==                \* CatFormView onSkip: tempCatData.name is left as it was
  /\ InOnboarding /\ step = "cat"
  /\ step' = "tasks"
  /\ Keep(<<flag, named, picked, pre, post, staged, saved, alert, noCatChosen, perm>>)

PickTask ==               \* TaskSetupView.tick: selectedTasks.insert
  /\ InOnboarding /\ step = "tasks" /\ picked = FALSE
  /\ picked' = TRUE
  /\ Keep(<<flag, step, named, pre, post, staged, saved, alert, noCatChosen, perm>>)

Back ==                   \* OnboardingHeaderView back button -> OnboardingView.goBack.
                          \* Not disabled while finish() runs; blocked only by the alert.
  /\ InOnboarding /\ step # "welcome"
  /\ ~(alert /\ step = "tasks")
  /\ step' = CASE step = "permission" -> "welcome"
               [] step = "cat"        -> "permission"
               [] step = "tasks"      -> "cat"
  /\ Keep(<<flag, named, picked, pre, post, staged, saved, alert, noCatChosen, perm>>)

\* ---- The finish step (OnboardingTaskSetupModel, OnboardingDataBuilder) ----

\* finish() up to its first await: the isFinishing guard, isFinishing = true,
\* isShowingSaveFailure = false. Each tap on Start runs its own Task { await model.finish() }.
StartFinish ==
  /\ (FinishGuard => Running = 0)
  /\ pre' = pre + 1
  /\ alert' = FALSE
  /\ Keep(<<flag, step, named, picked, post, staged, saved, noCatChosen, perm>>)

TapStart ==               \* TaskSetupView Start button (not disabled while finishing)
  /\ InOnboarding /\ step = "tasks" /\ alert = FALSE
  /\ StartFinish

Retry ==                  \* save-failure alert "Try again" -> retry() -> finish()
  /\ InOnboarding /\ step = "tasks" /\ alert = TRUE
  /\ StartFinish

\* The first commit succeeds: createCatAndTasks -> (empty name: modelContext.save) or
\* (cat + tasks inserted, first taskWriter.save commits them all at once; cats a failed
\* earlier attempt left staged are committed with them).
\* With no starter task, or no cat, there is no await after the commit, so finish()
\* returns .completed and calls completeOnboarding in the same step.
CommitSucceeds ==
  /\ pre > 0
  /\ pre' = pre - 1
  /\ saved' = saved + staged + (IF named THEN 1 ELSE 0)
  /\ staged' = 0
  /\ IF named /\ picked
       THEN /\ post' = post + 1                        \* awaits the reminder resync
            /\ Keep(<<flag, noCatChosen>>)
       ELSE /\ post' = post
            /\ flag' = TRUE                            \* completeOnboarding()
            /\ noCatChosen' = (noCatChosen \/ ~named)
  /\ Keep(<<step, named, picked, alert, perm>>)

\* The first commit throws: outcome .notSaved, isShowingSaveFailure = true.
\* OnboardingDataBuilder.unstage takes the cat back out of the context.
CommitFails ==
  /\ pre > 0
  /\ pre' = pre - 1
  /\ staged' = IF named /\ ~UnstageOnFail THEN staged + 1 ELSE staged
  /\ alert' = TRUE
  /\ flag' = IF FlagOnlyAfterSave THEN flag ELSE TRUE
  /\ Keep(<<step, named, picked, post, saved, noCatChosen, perm>>)

\* The later awaits finish: the full reminder resync and the other starter tasks' writes.
\* A reminder failure here is CareTaskRemindersOutOfSyncError -> .completed, same result.
RemindersSynced ==
  /\ post > 0
  /\ post' = post - 1
  /\ flag' = TRUE                                      \* completeOnboarding()
  /\ Keep(<<step, named, picked, pre, staged, saved, alert, noCatChosen, perm>>)

ContinueWithoutSaving ==  \* save-failure alert "Continue without saving"
  /\ InOnboarding /\ step = "tasks" /\ alert = TRUE
  /\ alert' = FALSE /\ flag' = TRUE /\ noCatChosen' = TRUE
  /\ Keep(<<step, named, picked, pre, post, staged, saved, perm>>)

\* ---- Outside events ----

\* The app is killed (swipe away, jetsam, crash) and opened again. UserDefaults and the
\* SwiftData store survive; OnboardingManager, the context's staged models and running
\* Tasks do not. A fresh OnboardingManager starts at .welcome with empty TempCatData.
KillAndRelaunch ==
  /\ InOnboarding
  /\ step' = "welcome" /\ named' = FALSE /\ picked' = FALSE
  /\ pre' = 0 /\ post' = 0 /\ staged' = 0 /\ alert' = FALSE
  /\ Keep(<<flag, saved, noCatChosen, perm>>)

\* A deep link or a notification tap while onboarding shows: ContentView.onOpenURL ->
\* NavigationRouter.handle sets tab and path state only. ContentView keeps showing
\* OnboardingView because it switches on hasCompletedOnboarding alone, so nothing here changes.
DeepLinkOrNotificationTap ==
  /\ InOnboarding
  /\ UNCHANGED vars

\* SettingsDebugViews (DEBUG builds only): OnboardingManager.resetOnboarding.
\* The household stays in the store; `saved` counts the new onboarding run from zero.
ResetOnboarding ==
  /\ flag = TRUE /\ Running = 0
  /\ flag' = FALSE /\ step' = "welcome" /\ named' = FALSE /\ picked' = FALSE
  /\ saved' = 0 /\ noCatChosen' = FALSE /\ alert' = FALSE
  /\ Keep(<<pre, post, staged, perm>>)

Next ==
  \/ WelcomeContinue \/ AllowNotifications \/ DenyNotifications \/ SkipNotifications
  \/ PermissionChangedInSettings
  \/ CatContinue \/ CatSkip \/ PickTask \/ Back
  \/ TapStart \/ Retry \/ CommitSucceeds \/ CommitFails \/ RemindersSynced
  \/ ContinueWithoutSaving
  \/ KillAndRelaunch \/ DeepLinkOrNotificationTap \/ ResetOnboarding

Spec == Init /\ [][Next]_vars

\* TLC counts states that differ only in `perm` as one. Sound here: `perm` changes which
\* permission button shows, never where a step leads (allow and deny both go to Your first
\* cat) and never a finish step. It keeps the first-run chart under the statechart budget.
FlowView == <<flag, step, named, picked, pre, post, staged, saved, alert, noCatChosen>>

\* Keeps the model finite when a broken variant lets finishes or cats pile up.
Bound == pre + post <= 2 /\ staged <= 2 /\ saved <= 2

\* ---- The rules ----

\* One onboarding run saves at most one first cat.
OneFirstCat == saved <= 1

\* Home shows a cat unless the caregiver chose to go on without one.
HomeHasCatUnlessChosen == flag => (saved >= 1 \/ noCatChosen)

\* While onboarding shows and no finish is running, this run has saved nothing:
\* a saved cat never sits behind an onboarding the caregiver must go through again.
NoSavedCatBehindOnboarding == (InOnboarding /\ Running = 0) => saved = 0

TypeOK ==
  /\ flag \in BOOLEAN /\ named \in BOOLEAN /\ picked \in BOOLEAN /\ alert \in BOOLEAN
  /\ noCatChosen \in BOOLEAN
  /\ step \in {"welcome", "permission", "cat", "tasks"}
  /\ perm \in {"notAsked", "allowed", "denied"}
  /\ pre \in Nat /\ post \in Nat /\ staged \in Nat /\ saved \in Nat
=============================================================================
