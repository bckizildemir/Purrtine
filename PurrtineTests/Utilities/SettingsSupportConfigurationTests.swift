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

    @Test(arguments: ["tr", "tr-TR"])
    func turkishUsesTurkishLegalPages(language: String) {
        let base = "https://bckizildemir.github.io/catcarecalendar-legal"

        #expect(SettingsSupportConfiguration.privacyURL(preferredLanguage: language)?.absoluteString
            == "\(base)/privacy-tr/")
        #expect(SettingsSupportConfiguration.termsURL(preferredLanguage: language)?.absoluteString
            == "\(base)/terms-tr/")
    }

    @Test(arguments: ["en", "en-US", "de", "", nil] as [String?])
    func otherLanguagesUseEnglishLegalPages(language: String?) {
        let base = "https://bckizildemir.github.io/catcarecalendar-legal"

        #expect(SettingsSupportConfiguration.privacyURL(preferredLanguage: language)?.absoluteString
            == "\(base)/privacy/")
        #expect(SettingsSupportConfiguration.termsURL(preferredLanguage: language)?.absoluteString
            == "\(base)/terms/")
    }
}
