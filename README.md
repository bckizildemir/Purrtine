# CatCareCalendar

CatCareCalendar is a local-first iOS app for cat owners. It keeps care routines, recurring tasks, reminders, and care history for several cats in one place. Everything lives on the device in SwiftData, so the app works fully offline. An optional task assistant turns a typed or spoken request ("feed Mia at 8 every morning") into a task; its fallback interpreter is the only feature that reaches a server.

Built with SwiftUI, SwiftData, and UserNotifications. The optional cloud tier uses Firebase (Auth, App Check, Cloud Functions).

## Requirements

- Xcode 26 or later
- iOS 18.4+ deployment target
- Node.js 22 and the Firebase CLI, only for the backend (`functions/`)

## Getting started

```bash
git clone https://github.com/bckizildemir/Purrtine.git
cd Purrtine
open CatCareCalendar.xcodeproj
```

Pick the `CatCareCalendar` scheme and an iOS simulator, then run.

No secrets file is needed. Without `GoogleService-Info.plist` the app launches normally with the cloud tier off; the task assistant then uses only its on-device interpreter.

### Use your own Firebase project

`GoogleService-Info.plist` is not in the repo. To turn on the cloud tier in a fork, create your own Firebase project with an iOS app, put its plist at `CatCareCalendar/GoogleService-Info.plist`, and deploy the function:

```bash
firebase use --add
firebase functions:secrets:set GROQ_API_KEY
firebase deploy --only functions
```

AI provider keys never ship in the app: they live in Firebase Functions secrets. `functions/.env.<project>` holds only the provider and model names.

## Tests

```bash
Scripts/xcb.sh test                                                   # whole suite
Scripts/xcb.sh test --only CatCareCalendarTests/TaskActionServiceTests
cd functions && npm test                                              # Cloud Function
```

Unit tests use Swift Testing; UI tests use XCTest. CI builds the app, runs the unit tests with a coverage floor, and builds Release on every push and pull request.

## Project layout

| Path | Contents |
| --- | --- |
| `CatCareCalendar/` | The iOS app: `Models/`, `Views/`, `Utilities/`, `Style/`, `Resources/` |
| `CatCareCalendarTests/`, `CatCareCalendarUITests/` | Unit and UI tests |
| `functions/` | Firebase Cloud Function for the task assistant's fallback interpreter |
| `Scripts/` | Build lock wrapper, coverage check |
| `documentation/` | Product requirements (`PRD.md`), feature specs, changelogs |
| `docs/` | Architecture notes, legal pages (GitHub Pages) |
| `CONTEXT.md`, `docs/adr/` | Domain language and architecture decision records |

## Contributing

Issues and pull requests are welcome. Read [`CLAUDE.md`](CLAUDE.md) for code style, localization rules (every string in English and Turkish), and testing expectations. Use Conventional Commit prefixes (`feat:`, `fix:`, `chore:`, `refactor:`, `docs:`).

## License

[MIT](LICENSE)
