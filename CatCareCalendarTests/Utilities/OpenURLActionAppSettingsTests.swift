import SwiftUI
import Testing
import UIKit
@testable import CatCareCalendar

@MainActor
struct OpenURLActionAppSettingsTests {
    @Test
    func openAppSettingsOpensTheAppSettingsPage() throws {
        var openedURLs: [URL] = []
        let openURL = OpenURLAction { url in
            openedURLs.append(url)
            return .handled
        }

        openURL.openAppSettings()

        let expectedURL = try #require(URL(string: UIApplication.openSettingsURLString))
        #expect(openedURLs == [expectedURL])
    }
}
