# Settings

More → Settings holds the app's preferences: reminder and notification settings, task display (default
view, theme, completed tasks), the Whiskers cloud toggle and caregivers. More → Support holds the legal and
support links: Rate App (App Store review page, id 6761329008, always shown since PR #101), Give Feedback
(mail), Privacy Policy and Terms of Service (web). The links open Safari, the App Store or Mail, outside
the app. Not yet proved (written from source 2026-11-07).

## Sub-features

- `settings-notifications` Settings → Notifications row (value Reminders On/Off, permission card).
- `settings-display` Settings → "Task & Display | Görev ve Görünüm": Default Task View (List | Calendar),
  Theme (System, Light, Dark; `settings.appearance.picker`), "Show Completed Tasks".
- `settings-whiskers` Settings → "Whiskers" row (`settings.taskAssistant.row`): the switch
  "AI-Assisted Understanding | Yapay Zeka Destekli Anlama" (consent for the cloud; see `whiskers.md`).
- `settings-caregivers` Settings → "Caregivers | Bakıcılar" (`settings.caregivers.row`).
- `settings-haptics` More → "Haptic Feedback | Dokunsal Geri Bildirim" switch.
- `support-links` More → "Support | Destek" → Rate App, Give Feedback, Privacy Policy, Terms of Service.
- `support-about` the About card: app name, "App Version 1.0 (1)"-style line, description.

## How to get to it (user POV)

- More | Daha Fazla tab → the "Settings | Ayarlar" row (`settings.appSettings.row`) → its rows.
- More tab → the "Support | Destek" row (`settings.support.row`) → the link rows.
- There is no language row: the app follows the device language (see the Turkish pass in `README.md`).
- More → Developer Tools exists in Debug builds (`settings.developerTools`); never use it.

## Driving it with axe

Preconditions:

- Onboarding is done; the More tab shows `settings.view`. If the tab shows an older screen, tap
  `BackButton` until it does (tabs keep their stack).

Steps:

- **Open More.** `vp tap --label More --element-type RadioButton` (Turkish `Daha Fazla`). The tree holds
  `settings.view`, `settings.shortcut.cats`, `settings.shortcut.history`, `settings.appSettings.row`,
  `settings.support.row`, the "Haptic Feedback" switch (no id) and `settings.developerTools`.
  `vp shot more-root`, `vp tree more-root`.
- **Settings screen.** `vp tap --id settings.appSettings.row`. Rows: `settings.notifications.row`, the
  Task & Display row (no id; label "Task & Display"), `settings.taskAssistant.row`,
  `settings.caregivers.row`. `vp tree settings-root`.
- **Display.** Tap the Task & Display row by label. Assert the Theme control `settings.appearance.picker`
  (segments System, Light, Dark; Turkish Sistem, Açık, Koyu). Tap `Dark`: the app turns dark at once
  (shot). Tap `System` again to restore. Switch "Show Completed Tasks" is a save-like toggle: use
  `vp tap --once`. Second view: Tasks tab filter chip `Completed` still shows; assert per `complete-task.md`.
- **Whiskers toggle.** `vp tap --id settings.taskAssistant.row`; the Switch "AI-Assisted Understanding".
  Read its value (0/1) in `vp ui`; toggle once with `vp tap --once --label "AI-Assisted Understanding"
  --element-type Switch`; the value flips. Footer text: "When Whiskers can't understand a request using
  what's already on your device, it can ask an AI service for help. Requests are never stored or used to
  train AI models." Second view: reopen the Whiskers tab chat (see `whiskers.md`): the consent sheet shows
  only while no answer exists; a toggled answer counts as answered.
- **Support screen.** Back out, `vp tap --id settings.support.row`. The tree holds the About card
  ("CatCareCalendar", "App Version <v> (<build>)", the description) and four link rows with ids:
  `settings.rateApp` ("Rate App | Uygulamayı Değerlendir"), `settings.giveFeedback` ("Give Feedback | Geri
  Bildirim Ver"), `settings.privacyPolicy` ("Privacy Policy | Gizlilik Politikası"),
  `settings.termsOfService` ("Terms of Service | Kullanım Koşulları"). Assert Rate App is present (PR #101:
  it always shows; before, an unset App Store id hid it). `vp shot support`, `vp tree support`.
- **Link targets.** The URLs are fixed in `SettingsSupportConfiguration`:
  - Privacy: `https://bckizildemir.github.io/catcarecalendar-legal/privacy/`
  - Terms: `https://bckizildemir.github.io/catcarecalendar-legal/terms/`
  - Rate App: `https://apps.apple.com/app/id6761329008?action=write-review`
  - Feedback: `mailto:bcankizildemir@gmail.com?subject=CatCareCalendar%20Support` (unless the Info.plist
    sets `SUPPORT_EMAIL`).
  Prove the target from the destination app, not from the app's source: tap a link with
  `vp tap --once --id settings.privacyPolicy`. The app goes to the background and Safari comes up. `vp tree
  link-privacy` and `vp shot link-privacy`: the tree holds Safari's address field with the host
  `bckizildemir.github.io` (read it from `vp ui`; the page may still load). Not proved: whether axe reads
  Safari's address bar; fall back to the screenshot.
- **Return, leaving nothing stuck.** `xcrun simctl terminate "$UDID" com.apple.mobilesafari`, then
  `xcrun simctl launch "$UDID" com.berkecankizildemir.CatCareCalendar` (no arguments: the app comes forward
  with its stack intact), then `vp ui` shows `settings.rateApp` again. Do the same for each link:
  Rate App opens the App Store app if the device has it (terminate `com.apple.AppStore`), else Safari on
  `apps.apple.com`; Give Feedback opens Mail (terminate `com.apple.mobilemail`), which on a fresh device may
  show a setup screen or do nothing: assert only that the app left or an alert showed, never a send.
- **Notifications row.** Back to Settings, `vp tap --id settings.notifications.row` (`notificationSettings.view`),
  the permission card `notificationSettings.permissionCard` shows only while permission is not authorized;
  see `reminder-nudge.md` for the Enable switch.
- **Haptic switch.** Back on More, `vp tap --once --label "Haptic Feedback" --element-type Switch`. Haptics are
  not observable; assert the value flips and restore it.
- **Record.** `echo "feature=settings entry=more-settings result=pass" >> <evidence>/run.txt`, and one
  line per link tested.

## Gotchas

- The four link rows are SwiftUI `Link`s: a tap leaves the app at once and the tree then belongs to the
  other app. Always bring the app back with `simctl launch` before the next step; never tap through
  Safari's own UI (cookie or welcome screens may show).
- A link may open nothing visible on a slim device (App Store app or Mail missing). Report that as "link
  tapped, app left / did not leave" with the shot; do not report the URL as verified.
- The identifiers of the four link rows come from `.accessibilityIdentifier(accessibilityIdentifier ?? "")`;
  if `vp ui` shows an empty id, match by label.
- Settings sub-rows without ids (Task & Display, the switches) are matched by label with
  `--element-type`; labels in Turkish are listed above.
- The Support screen title is "Support | Destek"; the Support row footer reads "Send questions or feedback
  anytime. | Sorularınızı ve geri bildirimlerinizi her zaman iletebilirsiniz."
- Run this recipe again in Turkish (`vp start --lang tr`); the About card and the footers are localized.
