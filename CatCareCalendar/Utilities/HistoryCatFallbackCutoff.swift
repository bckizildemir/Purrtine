import Foundation

/// The date of the first launch of a build with store schema V2.
///
/// History falls back to a task's assigned cats only for completions recorded before this date:
/// those are the rows that schema V1 may have stripped of their cat (see `HistoryPresentation`).
/// A completion made later is never given a guessed cat. On a fresh install the cutoff is the first
/// launch, so no completion is older than it and the fallback never applies.
///
/// The store is injected so a test can use its own `UserDefaults` suite.
struct HistoryCatFallbackCutoff {
    static let defaultsKey = "history.catFallbackCutoff"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The stored cutoff, or nil when none was recorded (no fallback then).
    var date: Date? {
        defaults.object(forKey: Self.defaultsKey) as? Date
    }

    /// Stores `now` once. A cutoff that already exists is never moved.
    func recordIfNeeded(now: Date = Date()) {
        guard date == nil else { return }
        defaults.set(now, forKey: Self.defaultsKey)
    }
}
