import Foundation
import SwiftData
import Synchronization

/// Waits for the save that commits a failed delete, whoever makes it, then runs the follow-up the
/// delete missed. A failed delete stays staged in the shared context, and the next successful save
/// commits it, so without a watch that save would land the delete with no resync and no cleanup
/// (#7 for tasks, #25 for cats).
///
/// One watch serves one context. Each pending delete carries a `Payload` — what its follow-up needs,
/// captured before the delete. One save that lands several pending deletes calls `onLanded` once,
/// with the payloads of every delete it landed. A save that lands none of them calls nothing.
///
/// Lifetime: `NotificationCenter` keeps the observer block, and the block keeps the watch and its
/// `onLanded` closure, until the last pending delete lands. The watch therefore outlives whoever armed
/// it. A delete that never lands keeps the watch until the process ends: the app quits first, or the
/// context goes away with the delete unsaved. The app's deletes run on the main context, which lives
/// as long as the app.
///
/// Autosave: the watch reacts to `ModelContext.didSave`, which an explicit `save()` posts. Whether an
/// autosave of the main context posts it is unverified: in the unit-test host, autosave did not commit
/// a staged delete within 10 seconds (2026-10-08), so the check proved nothing either way.
final class StagedDeleteWatch<Payload> {
    private(set) weak var context: ModelContext?
    /// The newest follow-up task. Written from the observer block, which runs on whatever thread
    /// saved, so it sits behind a lock rather than on the main actor.
    nonisolated let latestFollowUp = Mutex<Task<Void, Never>?>(nil)
    /// The failed deletes in this context that no save has committed yet.
    private var pendingPayloads: [PersistentIdentifier: Payload]
    private let onLanded: @MainActor ([Payload]) async -> Void
    private var observer: (any NSObjectProtocol)?

    /// False once every pending delete has landed and the observer is removed.
    var isObserving: Bool { observer != nil }

    /// Adds `modelId` to the watch for `context` in `watches`, or starts one there. A watch that has
    /// seen all its deletes land has stopped observing and is dropped here. An existing watch keeps
    /// the `onLanded` it was started with.
    static func watch(
        _ modelId: PersistentIdentifier,
        carrying payload: Payload,
        in context: ModelContext,
        among watches: inout [StagedDeleteWatch],
        onLanded: @escaping @MainActor ([Payload]) async -> Void
    ) {
        watches.removeAll { $0.isObserving == false }
        if let watch = watches.first(where: { $0.context === context }) {
            watch.pendingPayloads[modelId] = payload
        } else {
            watches.append(
                StagedDeleteWatch(watching: context, for: modelId, carrying: payload, onLanded: onLanded)
            )
        }
    }

    private init(
        watching context: ModelContext,
        for modelId: PersistentIdentifier,
        carrying payload: Payload,
        onLanded: @escaping @MainActor ([Payload]) async -> Void
    ) {
        self.context = context
        pendingPayloads = [modelId: payload]
        self.onLanded = onLanded
        // `@Sendable` keeps the block nonisolated: a save may post from another thread, where a
        // main-actor block would trap. It copies the IDs out, then hops to the main actor.
        observer = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: context,
            queue: nil
        ) { @Sendable [self] notification in
            let deletedIds = notification.userInfo?[ModelContext.NotificationKey.deletedIdentifiers.rawValue]
                as? [PersistentIdentifier] ?? []
            let followUp = Task { @MainActor in
                await self.followUpIfLanded(deletedIds)
            }
            latestFollowUp.withLock { $0 = followUp }
        }
    }

    private func followUpIfLanded(_ deletedIds: [PersistentIdentifier]) async {
        let landedPayloads = deletedIds.compactMap { pendingPayloads.removeValue(forKey: $0) }
        guard landedPayloads.isEmpty == false else { return }
        if pendingPayloads.isEmpty, let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        await onLanded(landedPayloads)
    }
}
