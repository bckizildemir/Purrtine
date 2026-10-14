---
name: testflight-release
description: Ship a new CatCareCalendar build to TestFlight external testers — checks for unpushed commits, updates the asc CLI, bumps the build number, archives/exports/uploads via App Store Connect, and assigns the build to External Testers and submits for Beta App Review. Use this whenever the user asks to "release", "ship", "push a new build", "send to TestFlight", "submit for external testing", or "update App Store Connect" for this app — even if they only mention one part of the pipeline (e.g. just "bump the version" or just "upload to ASC"), since these steps are normally done together.
---

# TestFlight release (CatCareCalendar)

This walks the whole path from "there's unshipped work sitting in a branch" to "a new build is live in TestFlight for external testers." Two Apple-side snags need attention: a Release-only compile break (Step 4) and an API key role that can block group assignment (Step 8).

Treat this as several checkpoints, not one script. **Stop and confirm with the user before any step that pushes to `main`, uploads a build to Apple, or submits for external review** — those are the same categories of action that always need explicit sign-off (see the top-level agent instructions on push/publish permissions). Everything read-only (git log, `asc` list/info commands, local builds) can run freely.

## Known identifiers for this app

Save yourself a lookup — these don't change often:

- App Store Connect app ID: `6761329008` ("Cat Care Calendar", bundle `com.berkecankizildemir.CatCareCalendar`)
- Team ID: `A355549DDD`
- External Testers group ID: `a6d6763f-f04a-46f7-a531-03a45170f5e5`
- Internal Testers group ID: `2737969c-77cf-48ed-ab37-ef07c015c9ae`

Still worth a quick `asc apps list` / `asc testflight groups list --app 6761329008` if it's been a while — IDs are stable but don't hardcode blindly forever.

## Step 1 — Find what isn't shipped yet

```bash
git fetch origin
git log origin/main..HEAD --oneline   # commits on current branch not on origin/main
git status                            # uncommitted changes
```

The user may *think* they pushed to main when really the work is sitting on a feature branch (this has happened before — double-check `git branch -vv` rather than trusting recollection). Ask how they want it onto main: push the branch and PR, merge locally and push, or just push the branch. Also ask about any uncommitted changes — usually they should be committed as part of the same release.

## Step 2 — Update the asc CLI

```bash
brew upgrade asc
asc doctor        # confirms keychain auth + profile are healthy
```

This is a routine tool update, not a risky action — just do it.

## Step 3 — Check the *real* version state before bumping

Don't trust `CURRENT_PROJECT_VERSION` in `project.pbxproj` as the source of truth — it can drift from what's actually on App Store Connect if a previous release bumped the build number only at archive time without committing it. Check ASC directly:

```bash
asc builds list --app 6761329008 --limit 5
asc versions list --app 6761329008 --platform IOS
```

Compare that against the local `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `CatCareCalendar.xcodeproj/project.pbxproj`. If they disagree, tell the user the discrepancy and ask what version/build number they actually want rather than guessing — don't just increment the local number blindly.

Bump `CURRENT_PROJECT_VERSION` (all six occurrences in the pbxproj — one per build config per target) with something like:

```bash
sed -i '' 's/CURRENT_PROJECT_VERSION = <old>;/CURRENT_PROJECT_VERSION = <new>;/g' CatCareCalendar.xcodeproj/project.pbxproj
```

Commit this alongside any other pending changes, merge to main per the user's answer in Step 1, then **ask before pushing** — pushing to `main` is shared state.

## Step 4 — Preflight the Release build before archiving

Release configuration compiles differently from Debug: anything gated `#if DEBUG` (like `Preview Content/PreviewHost.swift`) disappears, but call sites aren't always updated to match. This bit us once already — 23 view files called `PreviewHost` from ungated `#Preview { }` blocks, which compiled fine in Debug/Previews but broke the Release archive with "cannot find 'PreviewHost' in scope".

Before archiving, check for this class of problem:

```bash
grep -rl "PreviewHost(" CatCareCalendar --include="*.swift"
```

For each hit, confirm the `#Preview { ... }` block containing the call is wrapped in `#if DEBUG` / `#endif`. If a new one isn't, wrap it — the block is reliably the last thing in the file, ending at a lone `}` on its own line, so:

```python
# find the line starting with "#Preview", insert "#if DEBUG" before it,
# and "#endif" after the file's final line (verify last line is exactly "}")
```

More generally: if the archive step fails with "cannot find X in scope" for a Release-only build, suspect a DEBUG-gated symbol used from a call site that isn't itself DEBUG-gated, and look for the same pattern elsewhere in the codebase rather than patching just the one file the compiler happened to complain about first.

## Step 5 — Archive and export

```bash
xcodebuild -scheme CatCareCalendar -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath <scratch>/CatCareCalendar.xcarchive archive
```

Signing is Automatic (`CODE_SIGN_STYLE = Automatic`, team `A355549DDD`) so this should Just Work as long as the user is logged into Xcode with the right Apple ID. If it fails on signing, that's a "tell the user" moment, not something to route around.

Then export for App Store distribution:

```xml
<!-- ExportOptions.plist -->
<key>method</key><string>app-store-connect</string>
<key>teamID</key><string>A355549DDD</string>
<key>signingStyle</key><string>automatic</string>
<key>destination</key><string>export</string>
```

```bash
xcodebuild -exportArchive -archivePath <scratch>/CatCareCalendar.xcarchive \
  -exportPath <scratch>/export -exportOptionsPlist <scratch>/ExportOptions.plist
```

## Step 6 — Upload (ask first — this is a real upload to Apple)

```bash
asc builds upload --app 6761329008 --ipa <scratch>/export/CatCareCalendar.ipa --wait
```

This can take several minutes server-side (upload + Apple's processing). It's fine to run this via a backgrounded Bash call and wait for the completion notification rather than polling — don't sleep-loop checking on it.

Confirm the build reached `VALID`:

```bash
asc builds list --app 6761329008 --limit 3
```

## Step 7 — Export compliance (a one-time fix, then a per-build fallback)

New builds need an encryption/export-compliance answer before they can be assigned to an external group. If the app's Info.plist doesn't declare `ITSAppUsesNonExemptEncryption`, ASC has to be told per-build.

**Check first** whether this project's `Info.plist` generation (`GENERATE_INFOPLIST_FILE = YES` in the app target) already sets `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption`. If it's missing and the app genuinely doesn't use custom cryptography (only standard iOS APIs — true for this app), add it once so future builds skip this step entirely:

```
INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;
```

Add it right after `GENERATE_INFOPLIST_FILE = YES;` in **both** the Debug and Release configs of the `CatCareCalendar` app target only (not the test targets — they don't ship). Commit and push this alongside the version bump.

For a build that was already archived *before* this fix landed, you still need to set compliance for that specific build. Try the API first:

```bash
asc builds update --build-id <build-id> --uses-non-exempt-encryption=false
```

If it 403s ("API key in use does not allow this request"), see Step 8 — same permission ceiling, same fallback.

## Step 8 — Assign to External Testers and submit for review (ask first — visible to real testers)

```bash
asc publish testflight --app 6761329008 \
  --build <build-id> \
  --group a6d6763f-f04a-46f7-a531-03a45170f5e5 \
  --test-notes "<what changed in this build>" \
  --locale en-US \
  --submit --confirm
```

This one call both assigns the build to External Testers **and** submits it for Beta App Review. Verified working on build 10 (2026-07-21): it returns `{"betaReviewSubmitted":true, ...}` with the group id and exits 0.

The `asc` API key in the default auth profile (`asc doctor` names it) needs a role that can assign builds to external groups and submit for review. If this call 403s with "API key in use does not allow this request", it's a role limitation, not a missing flag — don't retry variations or attempt workarounds (re-auth with the same key, a different endpoint for the same effect, `--dry-run` tricks). Instead tell the user plainly and offer the two real options:
1. They finish it manually in the App Store Connect web UI (TestFlight → the group → add the build → Submit for Beta App Review) — usually under a minute.
2. They confirm/generate an API key with App Manager or Admin role in the `asc` auth profile, and you retry the CLI command.

## Summary of confirm-before-acting points

1. Pushing merged/bumped commits to `origin/main`
2. Uploading the `.ipa` to App Store Connect
3. Assigning a build to an external group / submitting for Beta App Review

Everything else (status checks, brew upgrade, local archive/export, grep/read-only ASC queries) can proceed without stopping.
