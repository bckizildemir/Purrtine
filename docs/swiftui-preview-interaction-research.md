# Research: can the owner interact with a SwiftUI preview from a Claude Code mod in herdr + Ghostty?

Date of research: 2026-11-17. Sources are first-party unless marked SECONDARY (Apple release notes and docs, Anthropic's mod API
types shipped with Claude Code 2.1.325, the herdr docs, the Ghostty and kitty sources, the Yazi docs and source, and the GitHub
repos of the tools named). "Fetched" means the research agent opened the page and read it. Anything it could not confirm from a
primary source is marked NOT VERIFIED and repeated in the last section. Nothing here was run on a simulator or in Xcode: the
research is read-only.

Important gap: https://code.claude.com/docs/en/plugins/mods/overview (and its sub-pages) returned `ECONNRESET` on every fetch
(six tries, two URLs). The mod API facts below therefore come from the type declarations that the running Claude Code writes for
mod authors (`claude-code.d.ts`, 24,139 lines, written by the `plugin-authoring` skill for build 2.1.325). That file is Anthropic's
own API contract with doc comments, but it is not the docs site, so a sentence on the docs site could say more.

## Short answers

1. **Interact with a live preview or simulator from a terminal: PARTLY.**
   - A standalone terminal program can do it today. `pisim` (MIT) shows a booted simulator in a herdr pane through the kitty
     graphics protocol and turns clicks and drags into taps and swipes. It runs in Ghostty and herdr, with about 0.1 s input
     latency by its own claim. It shows a *running app on a simulator*, not a `#Preview`.
   - Inside a Claude Code mod: NO as a supported path. `Image` and `Raster` are leaves with no `onPress` or hover. A `Client`
     element does receive pointer events (with sub-cell position) but it cannot contain an `Image` or `Raster`. Putting a
     `Client` over an `Image` with an absolutely positioned `Box` might work; nobody has tested it (NOT VERIFIED).
   - Lag: with the pisim method the pane updates at the simulator's frame rate; with a `simctl io screenshot` loop the author of
     `xcode-mods` measured about 1 fps and dropped the idea.
   - Another terminal (kitty, WezTerm, iTerm2) would not do clearly better. Ghostty already reports pixel mouse positions
     (mode 1016) and the kitty graphics protocol. iTerm2 is worse for images (PNG or RGBA bytes only).
2. **Does `RenderPreview` "interactive" mode allow input: NO.** It renders the preview interactively, waits `snapshotDelay`
   seconds, and returns a snapshot. Apple's only release note on it says "interactive delayed snapshots for macOS previews"
   (Xcode 27.3 beta). Whether it does anything on iOS is not documented. **Can `DeviceInteractionSynthesize` drive a preview:
   NOT DOCUMENTED, so no proof.** Apple says it lets agents "boot simulators, install and launch apps, synthesize touch events,
   and capture screenshots". Its tool text says it works on "a physical device or simulator" and it is made for a *running app*.
3. **`artemnovichkov/xcode-mods`: usable, MIT, static only.** It already does what our mod does (calls `RenderPreview`, shows
   the PNG with the `Image` element, history of 10, re-render after edits). It has no interaction with the preview itself, and
   its author tried and dropped a simulator mirror.
4. **A mod that lets the owner interact with a SwiftUI preview today: NO.** Nearest workable things, in order: (a) a mod
   button that opens the file in Xcode with `xed` and lets Xcode's own canvas Interactive mode do the work; (b) a pisim-style
   viewer in a herdr split pane, aimed at the app running in a simulator (needs a way to land on the screen you want).
5. **Yazi: center the image preview: PARTLY.** No config option exists. The built-in image previewer is top-left aligned by
   design (`pixel_area` copies `rect.x`, `rect.y`). A custom previewer plugin can pass its own `Rect` to `ya.image_show`.
   Cheaper: pad the PNG with transparent margins (our own inference, not documented).

## 1. Interaction from a terminal

### 1a. What the terminal protocols give

- **kitty graphics protocol** (fetched, first 100,000 of 125,801 characters): output only. It describes transmission by direct
  bytes, a file, a temp file and POSIX shared memory (`t=d|f|t|s`), z-index (negative z draws under text), placement over
  `c` columns by `r` rows, and Unicode placeholders. Its only input-related text is about answering queries. It has no mouse.
  https://sw.kovidgoyal.net/kitty/graphics-protocol/
- **Mouse** is a separate channel. Pixel-precise clicks need xterm mode 1016 (SGR-Pixels) on top of 1000/1002 and 1006.
  Ghostty's source lists all of them: `mouse_event_normal` 1000, `mouse_event_button` 1002, `mouse_event_any` 1003,
  `mouse_format_sgr` 1006, `mouse_format_sgr_pixels` 1016.
  https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/terminal/modes.zig
  Ghostty's docs page on features says only that it supports the kitty graphics protocol; it does not list mouse modes
  (https://ghostty.org/docs/features). The xterm control sequence page itself returned HTTP 403, so the 1016 wording was not read
  at the source (NOT VERIFIED beyond the Ghostty source).
- **herdr** passes pane images to the outer terminal: "Render pane images in Kitty graphics-compatible outer terminals" and
  "Applications use the standard Kitty graphics protocol through pane terminal output" (config reference, Socket API "Pane
  graphics"). It is "mouse-native" and forwards at least right-click gestures to "a mouse-reporting pane application".
  https://herdr.dev/llms-full.txt
  The herdr docs I could read do not say that left clicks, drags or pixel positions (1016) reach a pane application, and they
  do not mention 1016 at all. Two-thirds of the file was read; the rest may say more (NOT VERIFIED).

### 1b. Inside a Claude Code mod (mod API types, build 2.1.325)

- `Image` ("the terminal surface's picture leaf"): "A leaf: no children, `hover` or `onPress`". It draws PNG, RGBA, a file or a
  POSIX shared-memory frame. A keyed `Image` can be swapped with `$.ui.blit(...)` at "up to 120 a second taken, some sixty
  shown". The doc comment's own example is a streaming "browser" view with `{ shm, format: 'rgb', width: 1280, height: 720 }`.
- `Raster` ("the terminal surface's cell-grid leaf"): glyph, foreground and background per cell, up to 512 by 256 cells.
  "A leaf: no children, `hover` or `onPress` yet". So it is coarse (block and braille characters) and also cannot be clicked.
- `$.ui.blit({ requestId, key, cells | source })` repaints a mounted `Raster` or swaps a keyed `Image`. This is the frame-stream
  half of a mirror.
- `Client` is the pointer half. A mod draws it with a surface module (`module: "./x.tsx"`). `surface.onPointer(fn)` receives
  `down | move | up | enter | leave`, region-relative cells `x`, `y`, a `button`, modifiers, and `fine: { x, y }`, the sub-cell
  position "where the surface knows it: a terminal that reports pixels. kitty, Ghostty, iTerm2, WezTerm and foot do; tmux passes
  none through. ... What a module showing another program's pixels forwards." `surface.onKey` receives keys, and
  `surface.post(data)` sends plain data to the mod's `ui.message` hook.
- **The catch:** a surface module draws with `ClientElements = Omit<Elements['terminal'], 'Client' | 'Raster' | 'Image' | 'Progress'>`.
  A `Client` cannot contain a picture, and it cannot nest another `Client`.
- `Box` has `position: 'absolute'` with `top/left/right/bottom`. A design that puts an `Image` in the flow and an
  absolutely positioned `Box` holding a same-size `Client` on top is therefore expressible. Whether the blank `Client` cells
  would erase the picture, whether the `Client` keeps the pointer over the picture, and whether herdr forwards `fine` are all
  NOT VERIFIED.
- Surface: https://code.claude.com/docs/en/plugins/mods/overview could not be fetched (see the gap note at the top).

### 1c. Tools that stream a simulator

| Tool | What it does | Terminal? | Input | Licence |
|---|---|---|---|---|
| pisim (`@bitmonkey/pisim`, pi extension) | `/sim` splits a herdr pane and shows the booted simulator in its bezel. Frames come from the simulator's display buffer, are scaled on the GPU with Metal and sent as raw pixels over the kitty graphics protocol. Idle screen sends no frames. | Yes: herdr + Ghostty, kitty or WezTerm | Click = tap, drag = swipe or scroll, keys typed (US or UK layout), ctrl-y shortcuts. Single touch only. Input latency "about 0.1 s" (author's claim). Uses private Apple frameworks, following idb. | MIT |
| AXe (installed here) | `axe stream-video --udid ... --format mjpeg\|raw\|ffmpeg\|bgra --fps 1-30` ("using screenshot capture"), plus `tap`, `touch`, `swipe`, `drag`, `type`, `batch` ("one simulator/HID session") | No viewer, a building block | HID | see its repo |
| baguette (`tddworks/baguette`) | Headless simulator manager, claims 60 fps streaming and host-side input injection; web UI on 127.0.0.1:8421 | No (browser) | HID, multi-finger | Apache-2.0 |
| simpod | `simpod --no-preview` "streams the simulator in the terminal"; CLI taps with normalised coordinates | Claimed; page does not say how it draws or whether the mouse works | CLI | not named on the page |
| `xcrun simctl` | `io <device> recordVideo\|screenshot`; the local `simctl help` has no tap, touch or swipe command | No | None | Apple |

- Apple's own route to a human clicking is Device Hub: "Tap: Click" in the canvas, with the Mac pointer
  (https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub). Apple's command line page for
  devices (`devicectl`) documents install, launch and file copy but no tap.
- pisim facts are from its npm page and README and from `viewer.ts` (fetched): the viewer enables `?1000h ?1002h ?1006h ?1016h`,
  maps the pixel position to a fraction of the screen box, and sends `down`, `move`, `up` to its native helper. Frames go in with
  `a=T,f=24,t=t` (temp file, which the terminal reads and deletes), z-index raised each frame, on the main screen (no `?1049h`).
  https://github.com/bitmonkeyhouse/pisim and https://raw.githubusercontent.com/bitmonkeyhouse/pisim/main/viewer.ts
  This proves the loop "stream frames into a herdr pane, forward clicks as taps" is feasible, in this exact terminal stack,
  as a program that owns its pane. It does not prove it inside a Claude Code mod.
- Lag evidence: pisim "about 0.1 s" input (claim; I did not measure it). The `xcode-mods` plan file records the opposite
  result for a screenshot-based loop: "Sim Mirror tried in the Canvas mod, dropped: view-only ~1 fps not useful"; the idea was
  "`simctl io screenshot` + `$.ui.blit` loop". https://raw.githubusercontent.com/artemnovichkov/xcode-mods/main/docs/PLAN.md
  idb's own doc says the simulator may refresh less often than the requested fps (SECONDARY, search summary of
  https://fbidb.io/docs/idb/video). AXe's `stream-video` is also screenshot-based (its `--help`), so expect the 1 to 10 fps
  class, not 60. Only a framebuffer-callback method (pisim, baguette, idb) reaches the simulator's own frame rate.
- A frame stream and taps still show the *app on a simulator*. See question 2 for why that is not the same as a `#Preview`.

### 1d. Another terminal

Nothing in the sources says kitty, WezTerm or iTerm2 would do better than Ghostty. The mod types list kitty, Ghostty, iTerm2,
WezTerm and foot as terminals that report pixel positions. The same types say iTerm2 3.5+ draws only `png` and `rgba` bytes
for `Image` (no file or shared-memory frames), and herdr needs a "Kitty graphics-compatible outer terminal". pisim names
Ghostty, kitty and WezTerm. The deciding unknown is herdr in the middle, not the terminal.

## 2. Xcode's MCP tools

- `RenderPreview` (tool schema served by the connected Xcode MCP server): `displayMode` is `"static"` (default) or
  `"interactive"`. "\"interactive\" renders the preview interactively and then captures a snapshot, optionally after
  `snapshotDelay` seconds." `snapshotDelay` is "The time in seconds to let an interactive preview run before capturing its
  snapshot." The tool "waits until a snapshot of the resulting UI is available". There is no input parameter. So it is a
  delayed snapshot, as the owner already saw.
- Apple, Xcode 27.3 beta 2 release notes, Previews, New Features: "RenderPreview MCP tool now supports interactive delayed
  snapshots for macOS previews." Nothing in the notes says the same for iOS previews, so `displayMode: "interactive"` on an iOS
  simulator preview is not backed by Apple's notes (NOT VERIFIED). The same notes list the fix "Snapshots from the RenderPreview MCP
  tool could have the wrong resolution when the image was downscaled." and, for 27.2, "The RenderPreview MCP tool now returns
  the list of available render destinations, and lets the caller specify which destination to use for rendering."
  https://developer.apple.com/documentation/xcode-release-notes/xcode-27_3-release-notes
  https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes
- Other tools with input: `DeviceInteractionStartSession`, `DeviceInteractionStartWorkspaceSession`,
  `DeviceInteractionInstallAndRun`, `DeviceInteractionSynthesize`, `DeviceInteractionEndSession` (all in the connected server's
  tool list). `DeviceInteractionSynthesize`: "Synthesizes device events (tap, swipe, type, etc.) on a physical device or
  simulator and captures the resulting state", returns "paths to both files" (screenshot and UI hierarchy), takes
  `interactSessionKey`, `interactionCommand` (example `'t 100 200'` for a tap) and `activationBundleId` ("Bundle identifier of
  the app to activate before any interactions"). `DeviceInteractionInstallAndRun` "Builds, installs, and starts the current
  application on the currently targeted device".
- Apple's release note for it, Xcode 26.3 (Coding Intelligence): "Agents can now boot simulators, install and launch apps,
  synthesize touch events, and capture screenshots to verify UI behavior." (the 27 notes repeat it under New Features.)
  https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes
- **Can it drive a preview?** Not documented. The tool acts on a device by coordinates and wants an app bundle id. A preview
  is drawn by Xcode's preview host, and nothing I found says that host's UI is on a simulator screen that the session can tap.
  Treat as no until someone tries it (NOT VERIFIED). Apple's own pages on the MCP server
  (https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode) do not list the tools at all; the
  tool descriptions above are the only first-party text I found.
- Xcode's canvas does have a human-driven Interactive mode: Xcode 27 notes, "Clicking on a preview in argument or variant grids
  opens the preview in the Interactive mode."; 27.3 beta 2: "The software keyboard did not work in previews running on an iOS
  device." (fixed). So interaction with a preview exists, but in Xcode's UI, not through an MCP tool.

## 3. `artemnovichkov/xcode-mods`

https://github.com/artemnovichkov/xcode-mods (README, `canvas.tsx`, LICENSE, `docs/PLAN.md`, `CLAUDE.md` fetched).

- **What it does:** a Claude Code mod (plugin) that brings Xcode 27's headless MCP server into Claude Code: a toolbar band
  (scheme, destination, activity, problem counts), an "Xcode" pane with Build, Run and Tests tabs, and a "Canvas" pane with
  `#Preview` snapshots (last 10). Slash commands `/xcode`, `/build`, `/tests`, `/run`, `/stop`, `/preview [file.swift]`.
- **How it gets the image:** `canvas.tsx` calls `RenderPreview` with `sourceFilePath` and an optional `workspaceIdentifier`; it
  does not pass `displayMode`. It does not read image bytes from the result. It reads the `previewSnapshotPath` field of the
  result (preferring `structuredContent`, else JSON parsed after the first `{`) and shows that PNG file with
  `<Image source={{ file, format: 'png', generation }}>`. On the desktop app it makes a JPEG with `sips` and wraps it in an `Svg`.
  Without kitty graphics it shows the path and `o` opens the PNG. It maps the on-disk path to a project path with `XcodeGlob`.
  After an `Edit` or `Write` of a Swift file that contains `#Preview` it re-renders after 1,500 ms.
- **Interaction:** only with its own UI. Keys `r` re-render, `h`/`l` history, `o` open the PNG, `x` ask Claude to review; buttons
  use `onPress`. The source notes that wrapped button rows "lose mouse hit-testing". The preview picture itself is static. No
  pointer forwarding, no `Client`, no `Raster`. The plan file records a dropped "Sim Mirror" (about 1 fps, view-only).
- **Requires:** Xcode 27 or later with the MCP server in headless mode, Claude Code 2.1.286 or later (this machine has 2.1.326),
  a kitty-graphics terminal (its plan says "Ghostty (kitty graphics -> `Image` element works)"). The MCP server must be added
  as `xcode` and `mcp__xcode` allowed.
- **Licence:** MIT, "Copyright (c) 2026 Artem Novichkov" (root `LICENSE`; the plugin folder has its own `LICENSE` too).
- **Use or adapt:** yes under MIT, keeping the notice. It overlaps our mod; the useful parts are the `previewSnapshotPath`
  read, the `XcodeGlob` path mapping and the re-render-after-edit debounce. It gives no route to interaction. The repo's
  `.github/workflows/plugin-scan.yml` and `SECURITY.md` exist; I did not read them.

## 4. Bottom line

- **No** supported mod path to interact with a `#Preview` exists today. `RenderPreview` returns snapshots only, there is no
  documented tool that sends input to a preview, and the mod `Image` and `Raster` leaves take no clicks.
- **Closest workable (smallest first):**
  1. A `/preview-open` command or an `o`-style button in the mod that runs `$.process.run(["xed", "-l", "<line>", "<file>"])`
     (`$.process.run` takes an argv with no shell, its doc comment says so). `xed` opens the file in Xcode; `-b` keeps Xcode in
     the background. Its man page says nothing about showing the canvas or entering Interactive mode, so the owner still clicks
     "Live/Interactive" in Xcode's canvas (NOT VERIFIED: whether the canvas is visible after `xed`).
  2. Run the app, not the preview: build and launch with the app already on the screen under test, and use Device Hub, where
     "Tap: Click" is Apple's documented behaviour.
  3. A pisim-style viewer as a separate program in a herdr split pane. herdr documents
     `herdr pane split --current --direction right --no-focus` then `herdr pane run <pane_id> "<command>"`, and
     `HERDR_PANE_ID` for the calling pane. The viewer must own its pane's terminal (enable 1000/1002/1006/1016, draw with
     kitty graphics), exactly as `viewer.ts` does. pisim is MIT and its repo has `viewer.ts`, `simhelper.m`, `bezel.ts`; reuse
     needs its MIT notice and the idb NOTICE. It targets pi, not Claude Code; its agent tools are pi-specific, the viewer pane is
     not. This shows a *running app*; to see one preview that way, the app needs a launch path that shows that view as the root
     (our inference; Purrtine's `-ui-testing` flags are not the right switch for it).
  4. In-mod frame loop (`Image` + `$.ui.blit`) with a `Client` pointer overlay: expressible from the types, never shown to work
     (see 1b). Try it only as a spike: one `Image`, one absolutely positioned `Client` of the same size, log `onPointer` events,
     and check herdr passes `fine`.
- Smallest design for "interact" if the owner wants to try: option 3 for a simulator view, option 1 for previews.

## 5. Yazi: centering the image

- `yazi.toml` `[preview]` options (fetched, https://yazi-rs.github.io/docs/configuration/yazi/): `wrap`, `tab_size`, `max_width`,
  `max_height`, `cache_dir`, `image_delay`, `image_filter`, `image_quality`, `ueberzug_scale`, `ueberzug_offset`. No alignment or
  centering option. `ueberzug_offset` only exists "to work around an Überzug++ size calculation bug" and applies to Überzug++.
- Built-in previewer: `yazi-plugin/preset/plugins/image.lua` calls `ya.image_show(url, job.area)`.
  https://raw.githubusercontent.com/sxyazi/yazi/main/yazi-plugin/preset/plugins/image.lua
  In `yazi-adapter/src/image.rs`, `pixel_area` keeps `x: rect.x, y: rect.y` and only changes width and height, so the picture is
  top-left aligned inside the column.
  https://raw.githubusercontent.com/sxyazi/yazi/main/yazi-adapter/src/image.rs
- Plugin route: `ya.image_show(url, rect)` takes any `Rect` and "the image will downscale to fit the area automatically".
  https://yazi-rs.github.io/docs/plugins/utils/ A custom previewer registered for `image/*` could compute a centered `Rect`, but the
  docs I read do not document an image-size lookup, a `ui.Rect` constructor or the terminal cell size (the `Window` type has
  `rows`, `cols`, `width`, `height` in pixels), so a plugin would have to read the PNG size itself (NOT VERIFIED).
- Cheaper route (our inference): the previewer scales the picture to fit and draws from the top-left, so a PNG with transparent
  padding on the left and right (made when our mod copies the render into `~/preview-renders/`) shows the preview centered at
  one pane width. It is only centered for the column width it was padded for.

## Not verified

- Anything on code.claude.com (the mods docs): unreachable (`ECONNRESET`); all mod API facts are from the shipped types file.
- Whether a `Client` laid over an `Image` (absolute `Box`) leaves the picture visible and still receives the pointer.
- Whether herdr forwards left clicks, drags and pixel-position (1016) mouse reports to a mod running in a pane; whether
  Claude Code enables 1016 under herdr; whether herdr passes `t=s` (shared memory) and `t=t` image sources used by `Image`
  and `$.ui.blit`. pisim's README says its `t=t` frames work in herdr + Ghostty; I did not run it.
- xterm's wording for mode 1016 (page returned 403); Ghostty's behaviour was read from `modes.zig`, not run.
- Latency numbers: pisim's "about 0.1 s" is the author's claim; the ~1 fps figure is the `xcode-mods` author's note about a
  screenshot loop. AXe `tap` and `batch` latency, and `devicectl`/idb frame rates, were not measured.
- Whether `RenderPreview displayMode: "interactive"` does anything for iOS previews (Apple's note names macOS only).
- Whether `DeviceInteractionSynthesize` can tap a preview, the grammar of `interactionCommand` beyond the `t 100 200` example,
  and any Apple page listing the MCP tools (none found).
- Whether `xed` brings Xcode's canvas up or into Interactive mode.
- Whether a Yazi plugin can read image dimensions and cell size; what `ya.image_show` returns; exact padding behaviour.
- pisim, baguette and simpod were read from their pages and README, not built or run. simpod's licence is not stated on the
  page I read. `.github/workflows/plugin-scan.yml` in `xcode-mods` and its `SECURITY.md` were not read.
