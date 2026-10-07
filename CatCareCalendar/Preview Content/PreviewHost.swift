#if DEBUG
import SwiftData
import SwiftUI

@MainActor
struct PreviewHost<Content: View>: View {
    private let container: ModelContainer?
    private let content: Content
    @State private var navigationRouter = NavigationRouter()

    init(
        scenario: PreviewScenario = .standard,
        @ViewBuilder content: () -> Content
    ) {
        container = PreviewData.container(for: scenario)
        self.content = content()
    }

    var body: some View {
        if let container {
            content
                .environment(\.navigationRouter, navigationRouter)
                .environment(\.notificationManager, PreviewData.notificationManager)
                .defaultAppStorage(PreviewData.userDefaults)
                .modelContainer(container)
        } else {
            ContentUnavailableView(
                "Preview unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("The in-memory preview store could not be created.")
            )
        }
    }
}
#endif
