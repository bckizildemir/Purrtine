---
name: verify-purrtine
description: Drive the real CatCareCalendar (Purrtine) iOS app on a fresh, private simulator and capture proof of what a user sees — screenshots and accessibility trees of the real onboarding, add-cat, add-task and complete-task paths (all proved 2026-10-14 on iOS 26.5 and 2026-10-15 on iOS 27.0), in English or Turkish. Use when a PR needs a verify-purrtine proof, when asked to check a change in the running app, or when CLAUDE.md's "Verify trial" asks for a simulator check.
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
- One fresh slim simulator per run, one driver (owner, 2026-10-27). `$V start` clones the
  project's pristine SimSlim template `iPhone 12 slim tmpl (Purrtine)` (profile
  `Scripts/simslim-profile.json`: everything off except `photos` and `siri`), so each run starts
  as a brand-new user: no app, no data. Never boot the template, install on it, or touch any other
  simulator. One run per project at a time (the verify lock `/tmp/verify-purrtine.lock`); a TriQ
  run can drive at the same time. Machine-wide at most `SLIM_SIM_MAX` verify clones exist
  (default 2, shared with TriQ): `$V start` waits for a free slot.

## Launch

```bash
$V start                       # verify lock, fresh device, English; add --lang tr for Turkish
$V build                       # Scripts/xcb.sh build against this device; copies CatCareCalendar.app
$V hold                        # take the xcb lock for the drive (see "Why hold")
$V install
$V launch                      # prints "com.berkecankizildemir.CatCareCalendar: <pid>"
$V doctor                      # must exit 0
```

- `start` takes a verify slot, clones the template as `verify-purrtine-<run-id>` with
  `Scripts/slim-sim.sh clone` (iPhone 12, iOS 27.0; `--os 26.5` makes a template for that runtime
  on first use — see "Device choice"), boots it, sets its system language, reboots it, checks it
  with `simslim verify`, and makes the evidence folder
  `~/verify-evidence/purrtine/<YYYY-MM-DD>-<run-id>/` with `run.txt` (device, language, `slim=`,
  git rev). It takes about 55 s alone and about 1:45 when a TriQ run starts at the same moment
  (measured 2026-10-27). A failed `start` cleans up after itself.
- If a `build` is killed with SIGKILL its trap cannot run: run `$V cleanup` afterwards. SIGINT and
  SIGTERM stop the heartbeat and exit non-zero.
- `build` can wait up to an hour for the xcb build lock. Run it in the background
  (`run_in_background`), not in the foreground with a 10-minute timeout, and read its output when it
  finishes. An unchanged tree builds in about 40 s. A killed `build` stops its heartbeat loop.
- `launch` waits up to 30 s until axe reads a labelled tree.
- Ready means usable: `$V ui` lists the welcome screen — `Button | Get Started |
  onboarding.welcome.continueButton`. A fresh device always starts on the onboarding.
- Teardown is `$V cleanup` (see Cleanup).

### Why hold

A build or test from another session competes with the drive for this Mac's memory and CPU, and
before #80 (2026-10-15) `Scripts/xcb.sh test` also shut down every other booted simulator. On
2026-10-14 this run's device was shut down three times in 30 minutes that way. Since 2026-10-27
xcb never shuts down a simulator it did not boot: it tests on the project's own slim test device.
`$V hold` takes the same machine-wide lock that xcb uses, owned by a watcher process, so their
builds and tests wait while you drive. It ends at `$V cleanup`, or after 30 minutes
(`VP_HOLD_MAX=<seconds>` to change). Take it after `build` — `build` needs that lock itself — and
keep the drive short. If the device was shut down before the hold, `$V install` boots it again.
A second verify run (TriQ's, say) can clone and boot while you hold, but its `build` waits for
your hold to end.

**Owner decision (2026-10-14):** a drive may hold the xcb build lock for up to 30 minutes, which
pauses every build and test on the Mac, TriQ's too. Accepted. A longer pass re-runs `$V hold`.
`hold` depends on xcb's lock format: the `pid` and `owner` files in
`~/Library/Caches/xcb/build.lock`. A change to that lock in `Scripts/xcb.sh` must update `vp.sh` in
the same PR. `$V status` and `$V doctor` report whether the watcher process is alive.

## Doctor

`$V doctor` is read-only. It prints the run owner, the device state, whether the app is installed and
running, the app's command line (and fails on any test launch argument), the device language, and
the number of labelled accessibility elements. Run it first whenever anything looks off.

- `FAIL device is not booted` → another session shut it down (`simctl shutdown all`, or an `xcb.sh`
  older than 2026-10-27). `$V revive` boots it
  and relaunches the app; the app's data on the device stays. Retake the last step's evidence.
- `WARN app is not running` → `$V launch`.
- `WARN slim: the device does not match` → the clone lost its SimSlim profile. Run `$V cleanup` and
  start again; if it repeats, `Scripts/slim-sim.sh template` repairs the template.
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
$V tap --id onboarding.welcome.continueButton     # axe tap, physical style, waits 8 s, one retry if nothing changed
$V tap --once --id catForm.saveButton             # a tap that saves: never a second tap
$V tap --label Tasks --element-type RadioButton   # tab bar items are RadioButtons
$V tap --id catForm.nameField && axe type 'Miso' --udid $UDID
axe tap -x 195 -y 420 --tap-style physical --udid $UDID   # only when an element has no id or label
```

- Prefer `--id` (accessibility identifiers do not change with the language), then `--label` with
  `--element-type`.
- Use `$V tap`, not a bare `axe tap`. Measured 2026-10-14: the default tap style left the welcome
  screen unchanged twice, and a physical tap right after a screen change was lost once. `$V tap`
  taps with `--tap-style physical --wait-timeout 10`, waits up to 8 s for the tree to change, and taps
  once more only when it did not. `axe tap` itself exits 0 even when nothing happened.
- A tap that saves, completes, or toggles uses `$V tap --once`. A slow save can show after the wait,
  and a second tap would then save twice or untick a row. On its WARN, read `$V ui` before any retap.
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
  device's pending notification store into the evidence and counts the pending requests per title (more than 0 = scheduled; the app caps the total at 60).
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

It terminates the app, shuts down and deletes **this run's** clone (only a device named
`verify-purrtine-*` that the lock records) and frees its verify slot (`Scripts/slim-sim.sh
release`), releases the xcb hold and the verify lock, keeps the
evidence folder, and prints `du -sh ~/verify-evidence/purrtine`. Put that `du -sh` line in your
report, so the owner knows when to clean the folder. Run cleanup after a failed attempt too.

A crashed run leaves `/tmp/verify-purrtine.lock`. The next `$V start` treats it as stale when its
device no longer exists or nobody touched it for 45 minutes (`VP_STALE_MINUTES`), deletes that stale
`verify-purrtine-*` device, and goes on. The xcb hold watcher ends by itself when the verify lock goes.
A slot whose run lock is gone or has a heartbeat older than 45 minutes is freed (and its clone
deleted) by the next `start` of either project. `Scripts/slim-sim.sh slots` lists the slots.

## Device choice

The default is **iPhone 12, iOS 27.0**, the newest iOS (owner decision 2026-10-15; it was 26.5),
slimmed with SimSlim (owner decision 2026-10-27). Measured 2026-10-27 on iOS 27.0 with
`simslim measure`, a Purrtine and a TriQ clone booted at once, no app, 2 minutes idle: 1.03 GB / 119
processes and 1.01 GB / 122 processes (a stock iPhone 12: 2.65 GB / 295 processes). Each clone takes
about 400 MB of disk and is deleted at cleanup. The iOS 26.5 table below measured stock devices.
Override the model with `VP_DEVICE` or `--device`, and the version with `VP_OS` or `--os 26.5`; `start`
fails when this Mac has no runtime for that version (`xcrun simctl list runtimes`), and `build` passes
the version to `Scripts/xcb.sh` as `XCB_OS`. On 2026-10-13 a shared iOS 27.0 device's SpringBoard
crashed 11 times in two minutes at boot, then ran stable; if a fresh device loops like that, run
`$V cleanup` and start again, or use `--os 26.5` and say so in the report.

The model choice was measured on iOS 26.5, 2026-10-14, on this 16 GB M2 Air with `$V memory` (summed physical footprint of every process under the
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

- **Other sessions shut the device down.** Before #80, `Scripts/xcb.sh test` shut down every other
  booted simulator; since 2026-10-27 it shuts down none it did not boot. On 2026-10-14 a TriQ session's scratchpad
  script also ran `xcrun simctl shutdown all` before each of its own launches; nothing in this repo
  stops that. `$V doctor` names the shutdown; `$V revive` boots the device again
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
- **Slim services.** The profile keeps `photos` (photo picker) and `siri` (corespeechd: speech
  recognition); keychain, location and local notifications are never disabled. A feature that needs
  another category (iCloud, Contacts, push) fails on the clone: add the category to
  `Scripts/simslim-profile.json` in a PR (the template is re-slimmed on the next `start`), do not
  drive it on a stock device.
- **Lost taps.** See Drive: use `$V tap`.
- **Tabs keep their stack.** A tab reopens on the last screen pushed in it (More → My Cats stays open
  after Add a cat). Read `$V ui` and tap `BackButton` before you use the tab's root shortcuts.
- **Autocorrect.** Text fields keep the keyboard's autocorrect, and a save takes its suggestion
  (`Tarcin` saved as `Tar in`). Type real dictionary words.
- **No Simulator window needed.** On 2026-10-14 axe read the full tree with no Simulator app running,
  and `open -a Simulator` fails on this Mac (Xcode 27 has no `Simulator.app` in its usual place). The
  older note "an empty tree when the Simulator window is closed" did not reproduce; if `$V doctor`
  reports an empty tree, call xcodebuildmcp `open_sim`.
- **Out-of-process system UI.** The photo picker (`catForm.photoMenu` → Photo Library) runs out of
  process; axe sees none of its cells. The camera choice asks for camera access, and the simulator
  has no camera. Do not claim a photo path.
- **Debug-only screens exist.** More → Developer Tools (`settings.developerTools`) and its notification
  history are in every Debug build. Never use them for data or proof.
- **Cloud tier.** `GoogleService-Info.plist` is gitignored, so a fresh worktree has none and Firebase
  stays off. The owner's main checkout has it (seen 2026-10-14): the build then signs in to Firebase at
  launch, and the Whiskers assistant's cloud fallback calls a paid function. `$V doctor` warns; leave the
  assistant's cloud fallback alone in such a build.
- **The hold blocks every build on the Mac.** Keep a drive short. The watcher lets go after
  `VP_HOLD_MAX` seconds (default 1800) even if the run crashed; a crashed run's verify lock then goes
  stale after `VP_STALE_MINUTES` (45) more.
- **A system-sheet tap can report a change that did not happen.** On 2026-10-27 `$V tap --label Allow`
  on the notification sheet said "screen changed", but the sheet stayed ("Requesting permission…").
  `axe tap -x X -y Y --tap-style physical --udid $UDID` on Allow's frame centre (from `$V ui`)
  worked. After any tap on a system sheet, read `$V ui` and check the sheet is gone before the next step.
- **A screenshot with no device names the wrong one.** With several simulators booted (2026-10-27),
  xcodebuildmcp `screenshot` with no `simulatorId` captured another simulator. Take evidence with
  `$V shot`, or pass `simulatorId=$UDID` (the clone's UDID) to every xcodebuildmcp call.
- **`$V reminders` reads the first pending store on the device.** On a fresh device only this app
  schedules notifications, so that store is the app's.

## Helpers

- `scripts/vp.sh` — the run: `start [--device NAME] [--os 27.0|26.5] [--lang en|tr]`, `build`, `hold`, `install`,
  `launch`, `doctor`, `ui`, `tap AXE-ARGS…`, `shot NAME`, `tree NAME`, `reminders TITLE…`, `memory`,
  `revive`, `cleanup`, `status`. `$V` alone prints this list.
- `Scripts/slim-sim.sh` (repo root, shared with TriQ) — `template`, `test-sim`, `clone`, `release`,
  `slots`. `$V start` and `$V cleanup` call it; run `slots` to see who holds the verify slots.
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
