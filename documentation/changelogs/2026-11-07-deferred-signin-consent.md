# 2026-11-07 — Anonymous sign-in waits for consent; consent text names Firebase and Groq (#12, part)

Every launch used to sign the user in to Firebase anonymously, so every user got a Firebase account
even if they never used Whiskers. The sign-in now happens only on the first cloud interpreter call,
and that call only runs after the user has given cloud consent.

## What changed

- `CatCareCalendarApp` still calls `FirebaseBootstrapper.configureIfNeeded()` after the first frame:
  configuring creates no account, and the App Check provider must be set before the SDK configures.
  It no longer signs in.
- `FirebaseBootstrapper.ensureSignedInAnonymously()` now throws (`firebaseNotConfigured`, `signInFailed`).
- `FirebaseTaskAssistantCloudInterpreter` takes a `signIn` closure (default: the bootstrapper) and
  awaits it before each call. A failure throws, so `TaskAssistantViewModel` keeps the heuristic
  answer, as it does for any cloud failure.
- `task.assistant.cloud_consent_message` (en + tr) names the Firebase server in the EU and Groq, says
  the data is not used for training, and says Groq may keep it up to 30 days only to fix errors or
  stop abuse. Sources: https://console.groq.com/docs/your-data and Groq Services Agreement 4.2.
- `docs/legal/privacy/index.html` (English and Turkish summary) says the same and that the anonymous
  session starts only on first cloud use. The line "requests are not retained" is replaced.

## Tests

`FirebaseTaskAssistantCloudInterpreterTests`: building the adapter does not sign in; a call signs in
first; a sign-in failure is the call's error; no consent means no sign-in; consent means one sign-in
and a sign-in failure keeps the heuristic answer.
