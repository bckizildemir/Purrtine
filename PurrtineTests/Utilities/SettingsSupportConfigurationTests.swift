import Foundation
import Testing
@testable import Purrtine

@MainActor
struct SettingsSupportConfigurationTests {
    @Test(arguments: [nil, "", "   "] as [String?])
    func reviewURLFallsBackToPublishedAppStoreID(infoPlistValue: String?) {
        let url = SettingsSupportConfiguration.appStoreReviewURL(infoPlistAppStoreID: infoPlistValue)

        #expect(url?.absoluteString == "https://apps.apple.com/app/id6761329008?action=write-review")
    }

    @Test
    func reviewURLPrefersConfiguredAppStoreID() {
        let url = SettingsSupportConfiguration.appStoreReviewURL(infoPlistAppStoreID: "123456789")

        #expect(url?.absoluteString == "https://apps.apple.com/app/id123456789?action=write-review")
    }
}
