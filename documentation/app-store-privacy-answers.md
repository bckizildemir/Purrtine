# App Store Connect: App Privacy answers

These answers match `Purrtine/PrivacyInfo.xcprivacy`. Keep both in sync.

## Tracking

- Does the app track users? **No.** (`NSPrivacyTracking` = false, no tracking domains.)

## Data collection

Question: "Do you or your third-party partners collect data from this app?" Answer **Yes**, for two data types.
The app is local-first. Cats, tasks, photos and history stay on the device. Only the Task Assistant cloud
fallback sends data, and only after the user consents in the app.

| Data type (App Store Connect) | Manifest key | Collected | Linked to the user | Used for tracking | Purpose |
| --- | --- | --- | --- | --- | --- |
| User Content > Other User Content | `NSPrivacyCollectedDataTypeOtherUserContent` | Yes | No | No | App Functionality |
| Identifiers > User ID | `NSPrivacyCollectedDataTypeUserID` | Yes | No | No | App Functionality |

### Why each type

- **Other User Content.** Only after the user consents to the cloud assistant, the Task Assistant sends the typed
  or dictated request text, plus task titles and cat names, to the Firebase Cloud Function and on to Groq to
  interpret the request. A user who never consents sends nothing. It is not linked to an identity.
- **User ID.** Only after the user consents to the cloud assistant, the app signs in anonymously with Firebase
  Authentication, on the first Task Assistant cloud request. The anonymous uid authorizes calls to the Cloud
  Function (with App Check). It is not linked to a name, email or any other identity. A user who never consents
  gets no uid.

### Everything else: not collected

Contact info, health and fitness, financial info, location, sensitive info, contacts, browsing history,
search history, purchases, usage data, diagnostics, and any other data types. Photos stay on the device.

## Required-reason APIs (privacy manifest)

- `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` (the app reads and writes its own settings).

The Firebase SDK ships its own privacy manifests; they are not duplicated here.
