import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore

/// App Attest requires a physical device with a Secure Enclave and never works on
/// Simulator, so DEBUG builds use the debug provider instead (its per-install token
/// must be registered in the Firebase console — see App Check settings for this app).
/// Nonisolated because Firebase may call `createProvider(with:)` off the main thread, and a
/// main-actor `@objc` entry point would trap there.
nonisolated private final class AppAttestCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        AppAttestProvider(app: app)
    }
}

@MainActor
enum FirebaseBootstrapper {
    private static let signInOperation = InFlightMainActorOperation()

    static func configureIfNeeded() {
        guard FirebaseApp.app() == nil else { return }

        // The cloud tier is optional and its GoogleService-Info.plist is gitignored, so
        // the file is absent from fresh checkouts and CI. A bare `FirebaseApp.configure()`
        // hard-aborts the whole app at launch when the plist is missing — which would
        // crash every launch (and every UI test) in those environments. Load the options
        // ourselves so a missing config degrades the cloud assistant gracefully (see the
        // matching `FirebaseApp.app() != nil` guard in TaskAssistantCloudInterpreter)
        // instead of taking the app down.
        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: plistPath) else {
            print("[FirebaseBootstrapper] GoogleService-Info.plist not found in bundle; "
                + "skipping Firebase configuration. Cloud assistant features are disabled.")
            return
        }

        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestCheckProviderFactory())
        #endif

        FirebaseApp.configure(options: options)
    }

    /// The task assistant's cloud tier is gated on Firebase Auth (anonymous is enough —
    /// this app has no accounts), so every device needs a signed-in session before it
    /// can call the interpretation function.
    static func ensureSignedInAnonymously() async {
        // `Auth.auth()` raises if Firebase was never configured (missing plist — see
        // configureIfNeeded()), so skip sign-in entirely in that case.
        guard FirebaseApp.app() != nil else { return }

        await signInOperation.run {
            guard Auth.auth().currentUser == nil else { return }

            do {
                try await Auth.auth().signInAnonymously()
            } catch {
                print("[FirebaseBootstrapper] Anonymous sign-in failed: \(error)")
            }
        }
    }
}
