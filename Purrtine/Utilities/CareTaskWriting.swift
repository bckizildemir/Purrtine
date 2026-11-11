import Foundation
import SwiftData

/// The one way to write a care task. Every verb commits its store change first, then awaits one full
/// resync, which brings every care-task reminder in line with the store, before it returns.
///
/// **The guarantee:** when a method returns without throwing, the reminders for every task it
/// touched match the store. A caller has no scheduler to reach, so it cannot forget the resync.
///
/// Failures come in two kinds, and a caller has to tell them apart:
/// - Any error thrown *before* the commit (a model-context save, a validation) means nothing was
///   written. What the verb itself staged is taken back out of the context too, so a later save
///   cannot commit it; changes the caller staged before the call, such as form edits to an existing
///   task, stay pending. A task that was never committed counts as the verb's own and is removed.
///   The one exception is `delete`: its staged delete cannot be undone, so a later save commits it.
///   The verb drops the task's snoozes at once, and a later explicit `save()` that commits the
///   delete runs one full resync, so the task's reminders still go (#7). Whether an autosave that
///   commits it does the same is unverified; see `CareTaskWriter`.
/// - `CareTaskRemindersOutOfSyncError` means the write committed but the reminders could not be
///   brought in line. The data edit stands; only the reminders are stale.
///
/// A `CancellationError` passes through unwrapped, so callers filter it first. When one arrives
/// after the commit, the write stands and the next resync rebuilds the reminders from the store.
///
/// No explicit `@MainActor`: the app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and
/// every verb takes SwiftData models, which must stay on the actor that owns their context.
protocol CareTaskWriting {
    /// Inserts `task` if it is new, commits, and resyncs the reminders. Covers create and edit.
    func save(_ task: CareTask, in context: ModelContext) async throws

    /// Deletes `task`, commits, and resyncs the reminders, which drops the task's. A failed commit
    /// still drops the task's snoozes; see the type's note on failures.
    func delete(_ task: CareTask, in context: ModelContext) async throws

    /// Records a completion of `task`, commits, and resyncs the reminders. Delivered reminders for
    /// the task are cleared and the badge is recounted either way.
    func complete(
        _ task: CareTask,
        with input: CareTaskCompletionInput,
        in context: ModelContext
    ) async throws

    /// Schedules a one-off reminder `minutes` from now. Writes nothing to the store.
    func snooze(_ task: CareTask, minutes: Int) async throws

    /// Resyncs the reminders after a change *outside* the tasks with `taskIds`, such as a cat rename
    /// or delete. The resync covers every task; `taskIds` names the ones a failure reports as stale,
    /// and an empty list resyncs nothing.
    func refreshReminders(for taskIds: [UUID], in context: ModelContext) async throws
}
