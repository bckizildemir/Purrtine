import Foundation

enum SettingsSupportConfiguration {
    static var privacyURL: URL? {
        URL(string: "https://bckizildemir.github.io/catcarecalendar-legal/privacy/")
    }

    static var termsURL: URL? {
        URL(string: "https://bckizildemir.github.io/catcarecalendar-legal/terms/")
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
