import Foundation
import Testing
@testable import Purrtine

@MainActor
struct HistoryCatFallbackCutoffTests {
    private func makeDefaults() throws -> UserDefaults {
        let name = "HistoryCatFallbackCutoffTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test
    func noCutoffIsStoredUntilRecorded() throws {
        #expect(HistoryCatFallbackCutoff(defaults: try makeDefaults()).date == nil)
    }

    @Test
    func recordsTheFirstLaunchOnceAndNeverMovesIt() throws {
        let cutoff = HistoryCatFallbackCutoff(defaults: try makeDefaults())
        let first = Date(timeIntervalSince1970: 1_800_000_000)

        cutoff.recordIfNeeded(now: first)
        cutoff.recordIfNeeded(now: first.addingTimeInterval(86_400))

        #expect(cutoff.date == first)
    }
}
