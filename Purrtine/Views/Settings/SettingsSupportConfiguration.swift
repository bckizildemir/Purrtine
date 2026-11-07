import Foundation

enum SettingsSupportConfiguration {
    private static let legalBaseURL = "https://bckizildemir.github.io/catcarecalendar-legal"

    /// The language the app shows its own strings in: the first localization the main bundle
    /// resolved for the user's language list. `Locale.current` is the region format and can
    /// differ from the UI language, so it is not used here.
    private static var appLanguage: String? {
        Bundle.main.preferredLocalizations.first
    }

    static var privacyURL: URL? {
        privacyURL(preferredLanguage: appLanguage)
    }

    static var termsURL: URL? {
        termsURL(preferredLanguage: appLanguage)
    }

    static func privacyURL(preferredLanguage: String?) -> URL? {
        legalURL(page: "privacy", preferredLanguage: preferredLanguage)
    }

    static func termsURL(preferredLanguage: String?) -> URL? {
        legalURL(page: "terms", preferredLanguage: preferredLanguage)
    }

    /// Turkish gets the `-tr` page; every other language gets the English page.
    private static func legalURL(page: String, preferredLanguage: String?) -> URL? {
        let code = preferredLanguage?.split(separator: "-").first.map { $0.lowercased() }
        let folder = code == "tr" ? "\(page)-tr" : page
        return URL(string: "\(legalBaseURL)/\(folder)/")
    }

    static let publishedAppStoreID = "6761329008"

    static var appStoreReviewURL: URL? {
        appStoreReviewURL(infoPlistAppStoreID: bundleValue(for: "APP_STORE_ID"))
    }

    static func appStoreReviewURL(infoPlistAppStoreID: String?) -> URL? {
        let configuredID = infoPlistAppStoreID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let appStoreID = configuredID.isEmpty ? publishedAppStoreID : configuredID
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    static var contactSupportURL: URL? {
        let email = bundleValue(for: "SUPPORT_EMAIL") ?? "bcankizildemir@gmail.com"
        guard email.isEmpty == false else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Purrtine Support")
        ]
        return components.url
    }

    private static func bundleValue(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
