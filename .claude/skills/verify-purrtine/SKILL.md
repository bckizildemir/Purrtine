---
name: verify-purrtine
description: Drive the real CatCareCalendar (Purrtine) iOS app on a fresh, private simulator and capture proof of what a user sees — screenshots and accessibility trees of the real onboarding path (proved) and the add-cat, add-task and complete-task paths (unproved drafts), in English or Turkish. Use when a PR needs a verify-purrtine proof, when asked to check a change in the running app, or when CLAUDE.md's "Verify trial" asks for a simulator check.
---

# verify-purrtine

Prove a user-visible change in the real app: a Debug build, launched with no arguments, on a
simulator this run creates and deletes, with data entered only through screens a user has. The
evidence survives the run in `~/verify-evidence/purrtine/`.

Everything goes through one helper. From the repo root:

```bash
V=.claude/skills/verify-purrtine/scripts/vp.sh
```

`$V` with no argument lists the subcommands. The run state lives in `/tmp/verify-purrtine.lock/`
(`udid`, `evidence`, `owner`, …), so each new shell finds the same run:
`UDID=$(cat /tmp/verify-purrtine.lock/udid)`.

## Rules (owner decisions, 2026-10-14)

- Build only with `Scripts/xcb.sh` (`$V build` calls it). No `xcodebuild`, no xcodebuildmcp
  `build_*`/`build_run_sim`: they skip the machine-wide build lock.
- Launch with **no launch arguments**: never `-ui-testing`, `-keep-animations`, `-seed-*` or any
  other flag. Animations stay on; notifications are real.
- Data only through user screens: the onboarding, then Add Cat and Add Task. Never More →
  Developer Tools (Create Sample Data and the rest): the owner keeps it for manual catch-up.
- Not a harness: the XCUITest suite `CatCareCalendarUITests` and the `-ui-testing` mode.
- Drive with `axe` (or xcodebuildmcp `snapshot_ui`/`tap`/`type_text`/`screenshot` with this run's
  `simulatorId`) and `xcrun simctl`. Never osascript, never scripted mouse clicks: the owner works on
  the same Mac.
- One fresh simulator per run, one driver. Touch no other simulator — not the shared `iPhone 12`
  that TriQ and other sessions use. One verify run at a time: `$V start` waits for the verify lock.

## Launch

```bash
$V start                       # verify lock, fresh device, English; add --lang tr for Turkish
$V build                       # Scripts/xcb.sh build against this device; copies CatCareCalendar.app
$V hold                        # take the xcb lock for the drive (see "Why hold")
$V install
$V launch                      # prints "com.berkecankizildemir.CatCareCalendar: <pid>"
$V doctor                      # must exit 0
```

- `start` creates `verify-purrtine-<run-id>` (iPhone 12, iOS 26.5 — see "Device
  choice"), boots it, sets its system language, reboots it, and makes the evidence folder
  `~/verify-evidence/purrtine/<YYYY-MM-DD>-<run-id>/` with `run.txt` (device, language, git rev).
- `build` can wait up to an hour for the xcb build lock. Run it in the background
  (`run_in_background`), not in the foreground with a 10-minute timeout, and read its output when it
  finishes. An unchanged tree builds in about 40 s. A killed `build` stops its heartbeat loop.
- `launch` waits up to 30 s until axe reads a labelled tree.
- Ready means usable: `$V ui` lists the welcome screen — `Button | Get Started |
  onboarding.welcome.continueButton`. A fresh device always starts on the onboarding.
- Teardown is `$V cleanup` (see Cleanup).

### Why hold

`Scripts/xcb.sh test` shuts down **every other booted simulator** before it runs, and other sessions
(TriQ especially) run it often (`shut_down_other_simulators` in `Scripts/xcb.sh`). On 2026-10-14 this
run's device was shut down three times in 30 minutes by other sessions. `$V hold` takes the same machine-wide lock that xcb uses, owned by a watcher process,
so their tests wait while you drive. It ends at `$V cleanup`, or after 30 minutes
(`VP_HOLD_MAX=<seconds>` to change). Take it after `build` — `build` needs that lock itself — and
keep the drive short. If the device was shut down before the hold, `$V install` boots it again.

**Owner decision (2026-10-14):** a drive may hold the xcb build lock for up to 30 minutes, which
pauses every build and test on the Mac, TriQ's too. Accepted. A longer pass re-runs `$V hold`.
`hold` depends on xcb's lock format: the `pid` and `owner` files in
`~/Library/Caches/xcb/build.lock`. A change to that lock in `Scripts/xcb.sh` must update `vp.sh` in
the same PR. `$V status` and `$V doctor` report whether the watcher process is alive.

## Doctor

`$V doctor` is read-only. It prints the run owner, the device state, whether the app is installed and
running, the app's command line (and fails on any test launch argument), the device language, and
the number of labelled accessibility elements. Run it first whenever anything looks off.

- `FAIL device is not booted` → another session's `xcb.sh test` shut it down. `$V revive` boots it
  and relaunches the app; the app's data on the device stays. Retake the last step's evidence.
- `WARN app is not running` → `$V launch`.
- `WARN another simulator is booted` → owner decision: warn and continue. The run never shuts down a
  device it did not create. `start` and `doctor` print the warning.
- `WARN the hold watcher … is not running` → `$V hold` again (the 30 minutes ran out or it died).
- `WARN empty accessibility tree` → open the Simulator window (xcodebuildmcp `open_sim`) and retry.
- `WARN the app carries GoogleService-Info.plist` → the cloud tier is live in this build. Do not
  drive the Whiskers assistant into its cloud fallback: it calls a paid Firebase function.

## Drive

`axe` is on `PATH` (`/opt/homebrew/bin/axe`, 1.8.0). Read before every action, act, read again:

```bash
UDID=$(cat /tmp/verify-purrtine.lock/udid)
$V ui                                             # Type | Label | Id | Value | frame [disabled]
$V tap --id onboarding.welcome.continueButton     # axe tap, physical style, one retry if nothing changed
$V tap --label Tasks --element-type RadioButton   # tab bar items are RadioButtons
$V tap --id catForm.nameField && axe type 'Miso' --udid $UDID
axe tap -x 195 -y 420 --tap-style physical --udid $UDID   # only when an element has no id or label
```

- Prefer `--id` (accessibility identifiers do not change with the language), then `--label` with
  `--element-type`.
- Use `$V tap`, not a bare `axe tap`. Measured 2026-10-14: the default tap style left the welcome
  screen unchanged twice, and a physical tap right after a screen change was lost once. `$V tap`
  taps with `--tap-style physical --wait-timeout 10` and taps once more only when the tree did not
  change. `axe tap` itself exits 0 even when nothing happened.
- System alerts show in `$V ui` as SpringBoard elements: the notification prompt is a `Sheet` with
  buttons `Allow` and `Don’t Allow` (curly apostrophe; Turkish `İzin Ver`).
- xcodebuildmcp works too: pass `simulatorId=$UDID` to `snapshot_ui`, `tap` (element refs from
  `snapshot_ui` only), `type_text` and `screenshot`. Never call its `boot_sim`, `build_run_sim` or
  `session_set_defaults` with another device.

The recipes are in `features/` — read `features/README.md`, then the feature's file. Data comes only
from the journeys there: [Onboarding](features/onboarding.md) first, then Add Cat and Add Task.

## Evidence

```bash
$V shot onboarding-welcome      # PNG  -> <evidence>/NN-onboarding-welcome.png
$V tree onboarding-welcome      # JSON -> <evidence>/NN-onboarding-welcome.json
echo "feature=onboarding entry=first-launch result=pass" >> "$(cat /tmp/verify-purrtine.lock/evidence)/run.txt"
```

Proof standards:

- Real user path only: no launch flags, no Developer Tools, no test-only screens.
- Capture the action and the result: a shot before the step that matters and after it, plus a tree
  for every state you assert on.
- Prove a save from a second view (the list, Home, History), not from the sheet that closed.
- Side effects: a scheduled reminder is proved by `$V reminders "<task title>" …`, which copies the
  device's pending notification store into the evidence and counts each title (more than 0 = scheduled).
  A delivered banner needs its time to pass; prove it with a shot only when the change is about delivery.
  Say which side effects you did not prove.
- The system photo picker runs out of process; axe sees none of its cells. Never claim a photo pick.
- Add a `feature=… entry=… result=…` line to `run.txt` for each feature you drove.
- In the PR: attach the key screenshots (drag them into the PR description on GitHub, or upload with
  `gh`), and name the evidence folder and the feature files you followed.

## Cleanup

```bash
$V cleanup
```

It terminates the app, shuts down and deletes **this run's** device (only a device named
`verify-purrtine-*` that the lock records), releases the xcb hold and the verify lock, keeps the
evidence folder, and prints `du -sh ~/verify-evidence/purrtine`. Put that `du -sh` line in your
report, so the owner knows when to clean the folder. Run cleanup after a failed attempt too.

A crashed run leaves `/tmp/verify-purrtine.lock`. The next `$V start` treats it as stale when its
device no longer exists or nobody touched it for 45 minutes (`VP_STALE_MINUTES`), deletes that stale
`verify-purrtine-*` device, and goes on. The xcb hold watcher ends by itself when the verify lock goes.

## Device choice

The default is **iPhone 12, iOS 26.5** (`VP_DEVICE` or `--device` to override). Measured
2026-10-14 on this 16 GB M2 Air with `$V memory` (summed physical footprint of every process under the
device's `launchd_sim`), same protocol for both: fresh device, language set and rebooted, app launched
on the welcome screen, 2 minutes settle, then 6 samples 15 s apart.

| Device (iOS 26.5)          | Footprint samples (MiB)                 | Median   |
| -------------------------- | --------------------------------------- | -------- |
| iPhone SE (3rd generation) | 3822, 3825, 3827, 3833, 3922, 3923      | ~3830    |
| iPhone 12                  | 3899, 3899, 3899, 3928, 3988, 3988      | ~3914    |

The SE saves about 80 MiB (2 %), less than the drift inside one run (+100 MiB in 90 s as background
daemons start). That is not a real saving, so the iPhone 12 stays: it is the owner's baseline device
and the same screen size as the recorded runs. Measure again before you change the default.

## Gotchas

- **Other sessions shut the device down.** `Scripts/xcb.sh test` shuts down every other booted
  simulator (its "one simulator at a time" rule), and on 2026-10-14 a TriQ session's scratchpad script
  ran `xcrun simctl shutdown all` before each of its own launches. `$V hold` stops the first; nothing
  in this repo stops the second. `$V doctor` names the shutdown; `$V revive` boots the device again
  and relaunches the app with its data. A step that was in flight is lost: redo it from the last
  screen you proved. Onboarding saves nothing until "Start Tracking", so an onboarding cut short starts
  again at the welcome screen.
- **`xcb.sh` prints the wrong .app.** Its `xcb: app` line names the first `.app` in the products
  folder, which can be `CatCareCalendarUITests-Runner.app`. `$V build` takes `CatCareCalendar.app`
  from the same folder by name.
- **Shared DerivedData.** Every worktree builds into one DerivedData. `$V build` copies the app into
  the run's lock folder at once and fails when a newer CatCareCalendar build log exists; run it again.
- **A fresh device copies the Mac's languages** (`en-TR`, `tr-TR` on 2026-10-14). `$V start` always
  writes the device language (`en-US` or `tr-TR`) and reboots, so the language you asked for is the
  one the app sees. `$V doctor` prints it.
- **Lost taps.** See Drive: use `$V tap`.
- **No Simulator window needed.** On 2026-10-14 axe read the full tree with no Simulator app running,
  and `open -a Simulator` fails on this Mac (Xcode 27 has no `Simulator.app` in its usual place). The
  older note "an empty tree when the Simulator window is closed" did not reproduce; if `$V doctor`
  reports an empty tree, call xcodebuildmcp `open_sim`.
- **Out-of-process system UI.** The photo picker (`catForm.photoMenu` → Photo Library) runs out of
  process; axe sees none of its cells. The camera choice asks for camera access, and the simulator
  has no camera. Do not claim a photo path.
- **Debug-only screens exist.** More → Developer Tools (`settings.developerTools`) and its notification
  history are in every Debug build. Never use them for data or proof.
- **Cloud tier.** This checkout has no `GoogleService-Info.plist`, so Firebase stays off and the Whiskers
  assistant never calls the cloud. A checkout with the plist would call a paid function; `$V doctor`
  warns, and then you leave the assistant's cloud fallback alone.
- **The hold blocks every build on the Mac.** Keep a drive short. The watcher lets go after
  `VP_HOLD_MAX` seconds (default 1800) even if the run crashed; a crashed run's verify lock then goes
  stale after `VP_STALE_MINUTES` (45) more.
- **`$V reminders` reads the first pending store on the device.** On a fresh device only this app
  schedules notifications, so that store is the app's.

## Helpers

- `scripts/vp.sh` — the run: `start [--device NAME] [--lang en|tr]`, `build`, `hold`, `install`,
  `launch`, `doctor`, `ui`, `tap AXE-ARGS…`, `shot NAME`, `tree NAME`, `reminders TITLE…`, `memory`,
  `revive`, `cleanup`, `status`. `$V` alone prints this list.
- `scripts/sim-memory.sh UDID` — summed physical footprint (and RSS) of every process of one booted
  simulator, found under its `launchd_sim`. `$V memory` calls it for the run's device.

## Maintenance pass (`/maintain-verification-skill`)

A maintain pass drives **every** feature on **one** device, in one language, in one run: `start`,
`build` (background), `hold`, `install`, `launch`, `doctor`, then onboarding first and the other
features in the order of `features/README.md`. A full pass can outlast the 30-minute hold: when
`$V status` or `$V doctor` says the watcher is gone, run `$V hold` again before the next drive. Run
`$V doctor` before the first drive and after any failed drive; `$V revive` restores a device another
session shut down. Evidence stays in `~/verify-evidence/purrtine/`; teardown (`$V cleanup`) happens once,
after the last drive. A feature that cannot be reached is reported with the command tried and the
missing precondition. One language per device: a language change needs a reboot and a fresh start.

Keep the map honest as the app changes with `/maintain-verification-skill`.
