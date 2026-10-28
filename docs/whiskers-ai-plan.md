# Whiskers (Task Assistant) — AI and voice plan

Written 2026-10-16. Status: plan only. No code and no issues yet. The owner approved the five steps.

"Whiskers" is the owner's name for the **Task Assistant** (see `GLOSSARY.md`). The code types
start with `TaskAssistant`.

## Today

- Speech: `SFSpeechRecognizer()` with the device default locale writes into the text draft
  (`CatCareCalendar/Utilities/SpeechRecognitionService.swift`). The user sends the draft by hand.
- Interpretation: the local NaturalLanguage heuristic (`TaskAssistantInterpreter`) runs first. When
  it finds nothing, the consent-gated cloud tier (`FirebaseTaskAssistantCloudInterpreter` →
  callable `interpretTaskAssistantRequest` → Groq `llama-3.3-70b-versatile`,
  `functions/taskInterpreterProxy.js`) runs.
- Verbs: complete, postpone, open (`TaskAssistantAction`). Creation is the guided chip flow.
  There is no edit.
- Data: SwiftData, local-first. Target: iOS 18.4, Swift 6.0, `en` + `tr`.

## The plan, in order

### 1. Do issue #3 first — one understood intent

Four intent enums, five converters and nineteen switches mean each new verb touches all of
them. Collapse them into one typed command (for example `TaskCommand`) with a typed failure
case. Every later step adds a verb or a provider, so this step makes them cheap.

### 2. The model fills the typed command, not free text

Use Foundation Models `@Generable` output so the model returns a typed value.

- Create: "feed Mochi every day at 8" → a `TaskDraft` (name, cats, category, frequency, time).
  Open the existing chip flow pre-filled; the user confirms.
- Edit: "move the vet visit to Friday" → an edit command plus the same confirm step.
- Keep the rule: no action runs without confirmation (`confirmPendingAction`).

### 3. Three AI tiers behind the existing cloud seam, cheapest first

| Tier | Runs on | Cost | Notes |
| --- | --- | --- | --- |
| On-device `SystemLanguageModel` | iOS 26+, Apple Intelligence devices | free, offline | 4K context is enough for one spoken command. Give it a `findTasks` tool instead of the whole task list. No consent screen needed. |
| Private Cloud Compute `PrivateCloudComputeLanguageModel` | iOS 27+, Apple Intelligence devices | free for eligible developers | Use when on-device fails or the request needs reasoning. Needs the managed entitlement; per-user daily quota. |
| Groq via Firebase callable (today) | all devices | API fees | Fallback for iOS 18.4–25 and devices without Apple Intelligence. Keeps the consent gate. |

The local heuristic can stay in front of all three for exact matches. The first two tiers send no
task data to a third party, which fits the local-first design.

### 4. Better speech

- Set the recognizer locale from the app language, not the device default. A Turkish speaker on
  an English-locale phone gets wrong text today.
- On iOS 26+, evaluate `SpeechAnalyzer` / `SpeechTranscriber`.

### 5. App Intents — Whiskers through Siri

Make each care task an `AppEntity`, with intents for complete, postpone and create. Then
"Hey Siri, mark the litter box done in Purrtine" works without opening the app, and the same
intents serve Shortcuts, Spotlight and Apple Intelligence Siri.

## PCC eligibility

- App Store Small Business Program, fewer than 2M first-time downloads across **all** the
  developer's apps (Purrtine and TriQ share one account, so they share the limit), and the
  entitlement `com.apple.developer.private-cloud-compute`. Request:
  <https://developer.apple.com/contact/request/private-cloud-compute/>.
- Above 2M or out of the program → migrate within 6 months.
- Full research (eligibility, quota API, source conflict on the iCloud+ upgrade):
  TriQ `Documentation/AI_PRIVATE_CLOUD_COMPUTE_RESEARCH.md` (TriQ PR #95).

## Sources

- Apple: [Adding server-side intelligence with Private Cloud Compute](https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute)
- Apple: [PrivateCloudComputeLanguageModel](https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel)
- Apple: [Accessing Private Cloud Compute](https://developer.apple.com/private-cloud-compute/)
- Purrtine issue #3: "Deepen: one understood intent for the Task Assistant"
