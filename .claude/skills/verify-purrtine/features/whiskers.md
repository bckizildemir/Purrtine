# Whiskers (task assistant)

The Whiskers tab is a chat that completes, postpones or opens a task from a typed sentence. An
on-device heuristic answers first. Only when it finds no match, and only after the user allowed it, the
sentence goes to the cloud (Firebase function, then Groq). The first time a user opens the chat, a
consent sheet asks for that permission; the answer can be changed later in More → Settings → Whiskers.
Not yet proved (written from source 2026-11-07).

## Sub-features

- `whiskers-welcome` shows the welcome screen: "How can I help? | Nasıl yardımcı olabilirim?", up to
  three quick-action chips for tasks due today or overdue, and "Start Chat | Sohbeti Başlat".
- `whiskers-local` answers a sentence the heuristic understands, with no cloud: a confirmation card
  "Confirm Completion | Tamamlamayı Onayla" with Cancel and Confirm.
- `whiskers-consent` shows the consent sheet once, when the chat first appears.
- `whiskers-decline` "Don't Allow | İzin Verme": no cloud call ever; the sheet does not return.
- `whiskers-accept` "Allow | İzin Ver": unresolved sentences may go to the cloud.
- `whiskers-revoke` More → Settings → Whiskers toggle "AI-Assisted Understanding | Yapay Zeka Destekli
  Anlama" turns the consent off again (or on without the sheet).
- `whiskers-cloud` one cloud request: a sentence the heuristic cannot match, answered by the cloud.

## How to get to it (user POV)

- Whiskers tab (tab bar `RadioButton`, label `Whiskers`, same in Turkish) → welcome screen →
  "Start Chat" (`taskAssistant.startChatButton`). The chat pushes with the tab bar hidden; the X at the
  top left (`taskAssistant.endChatButton`) leaves it.
- A chip on the welcome screen (`taskAssistant.quickAction.<task title>`) also opens the chat, with a
  confirmation card already in it.
- Home → the Whiskers dock ("Whiskers", hint "Opens the Whiskers tab…") opens the same tab. It has no
  identifier in the source; use the label.
- Needs a cat and tasks: do [Onboarding](./onboarding.md) first (starter tasks Daily Feeding and
  Refresh Water are due today, so they show as chips). Data only from user screens.

## Driving it with axe

Preconditions:

- A run is open and onboarding is done, ticking Daily Feeding and Refresh Water.
- Consent was never answered: a fresh device has not. The answer is stored as the app's UserDefaults key
  `task_assistant_cloud_consent_granted`; a missing key means "not asked yet".
- **Cloud tier: can a verify build reach the cloud?** By default no. From the source:
  1. `GoogleService-Info.plist` is gitignored and `git ls-files` lists none, so a worktree build has none
     (checked 2026-11-07: `Purrtine/GoogleService-Info.plist` is absent in this worktree; the owner's
     main checkout `Purrtine/Purrtine/` has it). Without it `FirebaseBootstrapper.configureIfNeeded()`
     returns early, `ensureSignedInAnonymously()` throws `firebaseNotConfigured`, and the view model
     (`try? await cloudInterpreter.interpret…`) silently keeps the heuristic answer: the "No match" bubble.
  2. A no-flag launch is not blocked by `AppLaunchConfiguration.disablesCloudServices`: it is true only
     for `-ui-testing`, unit tests and previews. So the plist is the only gate.
  3. With the plist, a Debug build on a simulator uses `AppCheckDebugProviderFactory`, and the function is
     deployed with `enforceAppCheck: true` (`functions/index.js`). The debug provider makes a random token
     per install (a fresh clone has a new one every run); Firebase rejects calls until that token is
     registered in the Firebase console (App Check → the iOS app → Manage debug tokens). Until then the
     call fails and the chat looks exactly like the no-cloud case.
  4. Launch itself touches no Firebase (#12/#102): configuring, App Check and anonymous sign-in all start
     on the first consented cloud call.
  **NEEDS OWNER YES** before the `whiskers-cloud` step, one yes per action, each can cost money or change
  the owner's Firebase project: (a) copy the plist from the main checkout into the worktree's
  `Purrtine/` before `vp build` (local file, never commit it; `vp doctor` then WARNs "the app
  carries GoogleService-Info.plist", expected); (b) the owner registers one fixed App Check debug token in the
  console (App Check → the iOS app → Manage debug tokens) and keeps its value in the env var
  `PURRTINE_APPCHECK_DEBUG_TOKEN` or in a local file outside the repo (the owner's:
  `~/.config/purrtine/appcheck-debug-token`, mode 600). **Never write the token value into a recipe, a
  report, a commit or a PR; the repo is public.** Without a yes, report `whiskers-cloud` as "not reachable"
  and run everything else.
- **App Check debug token step (proved 2026-11-07).** The app ignores the `FIRAAppCheckDebugToken` environment
  variable (`SIMCTL_CHILD_…` did nothing). Write the token into the app container's defaults under the key
  `GACAppCheckDebugToken`, before the first cloud call, with the app not running:

  ```bash
  UDID=$(cat "$VP_LOCK_DIR/udid")        # /tmp/verify-purrtine.lock when VP_LOCK_DIR is unset
  BUNDLE=com.berkecankizildemir.CatCareCalendar
  # after `vp install` and one `vp launch` (so the container exists), then stop the app:
  xcrun simctl terminate "$UDID" "$BUNDLE"
  PREFS="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)/Library/Preferences/$BUNDLE"
  TOKEN="${PURRTINE_APPCHECK_DEBUG_TOKEN:-$(cat ~/.config/purrtine/appcheck-debug-token)}"
  xcrun simctl spawn "$UDID" defaults write "$PREFS" GACAppCheckDebugToken "$TOKEN"
  [ "$(xcrun simctl spawn "$UDID" defaults read "$PREFS" GACAppCheckDebugToken)" = "$TOKEN" ] && echo MATCH
  unset TOKEN
  ```
  Print only `MATCH`, never the value. Then `vp launch` again. Do not run broad `log show` filters that
  include AppCheck: the auto-mode classifier blocks them as credential materialization.
- **A cloud check only counts when the log or the screen shows a real cloud call.** The probe sentence must
  be one the local heuristic cannot match: screen it first with consent declined (it must give the no-match
  bubble; this costs no request). On 2026-11-07 "Topped up her bowl with fresh food this morning" was
  answered by the phone (a confirmation card), so that run proved nothing. Also not valid: sentences with a
  cat name or task words ("Miso", "refilled the drinking bowl", "Gave the little one her supper"). Evidence of
  a real call: the typing indicator right after Send, or the Function log (read only:
  `firebase functions:log`) showing "Callable request verification passed" for the run's time.
- **Reading a failed cloud call.** The Function log line `{"app":"VALID","auth":"VALID"}` followed by HTTP
  401 means App Check and sign-in passed and the Groq provider key is invalid ("AI provider key is invalid",
  reason `api-key-invalid`): the owner must fix the `GROQ_API_KEY` secret. The App Check token step does not
  fix that. The app shows only the no-match bubble in this case.
- **Cloud budget: at most 10 cloud requests in a whole pass.** Every sentence sent while consent is on
  and the heuristic did not match counts as one, even if it fails. Keep a tally in the evidence:
  `echo "cloud-request n=1 text=<sentence>" >> <evidence>/run.txt`; stop at 10.
- **Heuristic or cloud answer?** The heuristic's reply to a sentence it cannot match is always the
  failure bubble (red triangle) "I couldn't confidently match that to a task. Try the task name, cat
  name, or care type. | Bunu bir görevle güvenle eşleştiremedim. Görev adını, kedi adını veya bakım türünü
  dene." So: a no-match bubble = heuristic (or a failed cloud call); a confirmation card or a
  "Which one did you mean?" card for a sentence that gave a no-match while consent was off = cloud.
  While a cloud call runs, a typing indicator labelled "Whiskers is typing… | Whiskers yazıyor…" shows;
  the heuristic never shows it for a plain sentence.

Steps:

- **Welcome.** `vp tap --label Whiskers --element-type RadioButton`. The tree holds
  `taskAssistant.welcome` (the title text), `taskAssistant.startChatButton`, and the chips
  `taskAssistant.quickAction.Daily Feeding` and `taskAssistant.quickAction.Refresh Water` (label
  "Mark Daily Feeding done | Günlük Besleme tamamlandı olarak işaretle"). No consent sheet yet.
  `vp shot whiskers-welcome`, `vp tree whiskers-welcome`.
- **Consent sheet.** `vp tap --id taskAssistant.startChatButton`. The chat opens and the sheet slides up
  (`taskAssistant.cloudConsent` is set on the sheet's root view; if `vp ui` shows no such id, match the
  texts). Read the texts in EN and TR from `vp tree`:
  - Title: "AI-Assisted Understanding | Yapay Zeka Destekli Anlama".
  - Message EN: "If Whiskers can't understand a request on its own, it can send the request text, with
    your task and cat names, to our Firebase server in the EU and to Groq, an AI service. They are not
    used for training. Groq may keep them for up to 30 days only to fix errors or stop abuse. Change this
    anytime in Settings."
  - Message TR: "Whiskers bir isteği kendi başına anlayamazsa, istek metnini görev ve kedi adlarınla
    birlikte AB'deki Firebase sunucumuza ve bir yapay zeka servisi olan Groq'a gönderebilir. Bu veriler
    eğitim için kullanılmaz. Groq bunları yalnızca hataları gidermek veya kötüye kullanımı önlemek için en
    fazla 30 gün saklayabilir. Bunu istediğin zaman Ayarlar'dan değiştirebilirsin." ("sen" form since #107)
  - Buttons: "Don't Allow | İzin Verme" and "Allow | İzin Ver". Both carry the same id
    `taskAssistant.cloudConsent`, so `--id` is ambiguous, and `--label "Don't Allow"` found nothing
    (apostrophe). Tap by coordinates read from `vp ui` (iPhone 12: Don't Allow about (150,756), Allow
    (260,756); Turkish İzin Verme (142,756), İzin Ver (258,756)) with `axe tap -x X -y Y --tap-style physical`.
  `vp shot consent-medium`, `vp tree consent-medium`.
- **Scrolls, detents, no swipe-away.** The message sits in a scroll view and the two buttons are pinned
  below it. Swipe up inside the text (`axe swipe` with y values from the sheet's frame in `vp ui`) and
  check the buttons keep their frame. The sheet opens at the medium detent; drag its top edge up (from the
  grabber, read its position in `vp shot consent-medium`) and check it grows to the large detent
  (`consent-large` shot), then drag it back. Measured: the EN text fits the medium detent, so there is no
  inner scroll; dragging the grabber from (195,400) to (195,100) reaches "Expanded" (Turkish: (195,402) to
  (195,150); back with (195,66) to (195,450)). Swipe down from the top edge: the sheet must stay
  (`interactiveDismissDisabled`); only a button closes it.
- **Decline.** `axe tap` on the Don't Allow centre (Turkish: İzin Verme), see Buttons above. The sheet closes, the chat
  shows the composer (`taskAssistant.input`, placeholder "Message Whiskers… | Whiskers'a yaz…") and the
  empty state. Second view: leave with `vp tap --id taskAssistant.endChatButton`, tap
  `taskAssistant.startChatButton` again: no sheet. Settings: More → Settings → Whiskers (see
  `settings.md`): the "AI-Assisted Understanding" switch has value 0.
- **Local request.** Type into the composer: `vp tap --id taskAssistant.input --element-type TextField`
  (two elements share that id), wait 2 s and check the keyboard shows (the first tap is often lost), then
  `axe type 'Complete Refresh Water' --udid $UDID`, then
  `vp tap --once --label "Send task message" --element-type Button` (Turkish label `Görev mesajını gönder`;
  the button's id is also `taskAssistant.input`, there is no `taskAssistant.sendButton`). Turkish request:
  `Su Tazeleme tamamla`. Expected: a user bubble with the text and an assistant bubble
  `Complete "Refresh Water" for Miso today?` (Turkish `"Su Tazeleme" görevini Miso için bugün
  tamamlayayım mı?`), plus the card "Confirm Completion | Tamamlamayı Onayla" with
  `taskAssistant.cancelConfirmationButton` and `taskAssistant.confirmButton`. This ran with consent
  declined, so it is the on-device answer. If the heuristic asks which task instead, a card with
  `taskAssistant.suggestion.<title>` rows shows; tap the right one.
  `vp tap --once --id taskAssistant.confirmButton`. The chat adds `"Refresh Water" is complete.`
  Second view: Tasks tab, `taskRow.Refresh Water` reads `…, Tomorrow`; More → History has
  `history.row.Refresh Water` (see `complete-task.md`).
- **Screen a cloud probe at no cost.** While consent is declined, send a sentence that should need the
  cloud, for example `Miso finished her morning meal` (check that the heuristic really gives the no-match bubble). Only a sentence that gets the no-match bubble is
  a valid probe later; one the heuristic already answers is not. Cancel any card with the Cancel
  button. No cloud request happens here.
- **Accept.** Open Settings → Whiskers, switch "AI-Assisted Understanding" on (value 1): this answers the
  consent without the sheet. To test the sheet's Allow button as well, the consent must be unanswered,
  which only a fresh device is: run a second pass on a new device, or do the Allow branch first and the
  Decline branch second (a declined answer can be turned on in Settings, an answered one never shows the
  sheet again). Pick one order per run and record it.
- **Revoke.** More → Settings → Whiskers, switch the toggle off (value 0). Send the screened probe: the
  no-match bubble comes back at once and no typing indicator shows. Count nothing against the budget.
- **One cloud request** (only with the three NEEDS OWNER YES items done, and the consent on). Send the
  screened probe once. Read `vp ui` right after the send: the typing indicator may show. Then assert a
  confirmation or clarification card whose task is real and that a real call happened (see "A cloud check only counts…") (a title from the Tasks tab). A no-match bubble
  means the call failed: report which of the preconditions above is the likely cause, do not retry more
  than once. Cancel the card. Log it in the tally.
- **Record.** `echo "feature=whiskers entry=whiskers-tab result=pass" >> <evidence>/run.txt`, plus the
  cloud tally line.

## Gotchas

- The consent sheet shows when the chat appears, not on the welcome screen. It re-checks on every
  appearance, so it returns after the chat is left and re-entered only while no answer exists.
- The Settings toggle defaults to off while no answer exists, and turning it on stores "granted" without
  ever showing the sheet.
- The message bubbles have no identifiers: read their text from `vp ui` (the Text is the label).
- The sent text is kept in `viewModel.messages` for the chat's life only; ending the chat with the X
  clears it (`endChat`). A tab switch keeps the chat.
- A cloud success needs App Check, anonymous sign-in and the Groq secret to be live on the owner's
  project. A failure in any of them is invisible in the app (silent fallback), so a no-match bubble
  after Allow does not prove the call was skipped. The app's `print` lines (`[FirebaseBootstrapper] …`)
  show only in the console of `xcrun simctl launch --console`, which `vp launch` does not use.
- Dictation (`taskAssistant.micButton`) needs the speech service the slim profile keeps (`siri`) and a
  microphone permission prompt; it is not part of this recipe.
- Run this recipe again in Turkish (`vp start --lang tr`): the consent text and the card texts above
  have TR versions, and the heuristic accepts Turkish verbs ("tamamla", "ertele", "aç").
- Measured 2026-11-07 (English and Turkish passes): the welcome screen shows no chips when no task is due
  today (completed tasks move to Tomorrow), so check the chips before completing anything. Completing an
  already-done task asks "What would you like to do" (`taskAssistant.intent.complete`) before the confirm card;
  the "which one" card uses `taskAssistant.taskChoice.<title>` and `taskAssistant.cancelTaskDisambiguationButton`.
- The Settings footer (More → Settings → Whiskers) no longer says "never stored" since #107: it says Purrtine
  keeps no copy and Groq may keep a request up to 30 days, matching the consent sheet.
- Dismissing the consent sheet: only the buttons close it; a swipe down does not.
