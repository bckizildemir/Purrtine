import Foundation
import Testing

struct LocalizationParityTests {
    private static let supportedLocales = ["en", "tr"]
    private static let catalogNames = ["Localizable", "InfoPlist"]

    @Test
    func everyKeyIsTranslatedInEverySupportedLocale() throws {
        for catalogName in Self.catalogNames {
            let catalog = try loadCatalog(named: catalogName)

            #expect(catalog.strings.isEmpty == false)
            #expect(catalog.sourceLanguage == "en")

            for (key, entry) in catalog.strings {
                for locale in Self.supportedLocales {
                    guard let localization = entry.localizations[locale] else {
                        Issue.record("\(catalogName): key '\(key)' is missing a '\(locale)' localization")
                        continue
                    }

                    if let stringUnit = localization.stringUnit {
                        #expect(
                            stringUnit.state == "translated",
                            """
                            \(catalogName): key '\(key)' (\(locale)) has state \
                            '\(stringUnit.state)' instead of 'translated'
                            """
                        )
                        #expect(
                            stringUnit.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                            "\(catalogName): key '\(key)' (\(locale)) has a blank translated value"
                        )
                    } else if let plural = localization.variations?.plural {
                        #expect(
                            plural.isEmpty == false,
                            "\(catalogName): key '\(key)' (\(locale)) declares plural variations but has no categories"
                        )
                        for (category, variation) in plural {
                            #expect(
                                variation.stringUnit.state == "translated",
                                """
                                \(catalogName): key '\(key)' (\(locale), plural '\(category)') has state \
                                '\(variation.stringUnit.state)' instead of 'translated'
                                """
                            )
                            #expect(
                                variation.stringUnit.value
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty == false,
                                """
                                \(catalogName): key '\(key)' (\(locale), plural '\(category)') \
                                has a blank translated value
                                """
                            )
                        }
                    } else {
                        Issue.record(
                            """
                            \(catalogName): key '\(key)' (\(locale)) has neither a stringUnit \
                            nor plural variations
                            """
                        )
                    }
                }
            }
        }
    }

    @Test
    func pluralKeysDeclareTheSameCategoriesPerLocale() throws {
        let catalog = try loadCatalog(named: "Localizable")

        for (key, entry) in catalog.strings {
            let pluralLocales = entry.localizations.filter { $0.value.variations?.plural != nil }
            guard pluralLocales.isEmpty == false else { continue }

            #expect(
                Set(pluralLocales.keys) == Set(Self.supportedLocales),
                """
                Key '\(key)' uses plural variations in \(pluralLocales.keys.sorted()) \
                but not in every supported locale
                """
            )

            guard let referencePlural = pluralLocales[Self.supportedLocales[0]]?
                .variations?.plural else {
                continue
            }
            let expectedCategories = Set(referencePlural.keys)
            #expect(
                expectedCategories.contains("other"),
                "Key '\(key)' must define the required plural 'other' category"
            )
            for locale in Self.supportedLocales.dropFirst() {
                let categories = Set(
                    pluralLocales[locale]?.variations?.plural?.map(\.key) ?? []
                )
                #expect(
                    categories == expectedCategories,
                    """
                    Key '\(key)' has plural categories \(categories.sorted()) for \(locale), \
                    expected \(expectedCategories.sorted())
                    """
                )
            }
        }
    }

    @Test
    func infoPlistCatalogContainsRequiredPrivacyDescriptions() throws {
        let catalog = try loadCatalog(named: "InfoPlist")
        let requiredKeys = [
            "NSCameraUsageDescription",
            "NSMicrophoneUsageDescription",
            "NSSpeechRecognitionUsageDescription"
        ]

        for key in requiredKeys {
            #expect(catalog.strings[key] != nil, "InfoPlist is missing required privacy key '\(key)'")
        }
    }

    // MARK: - Catalog Loading

    private func loadCatalog(named name: String) throws -> StringCatalog {
        let catalogURL = repositoryRoot()
            .appending(path: "CatCareCalendar/Resources/\(name).xcstrings")
        let data = try Data(contentsOf: catalogURL)
        return try JSONDecoder().decode(StringCatalog.self, from: data)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

// MARK: - Minimal xcstrings Schema

private struct StringCatalog: Decodable {
    let sourceLanguage: String
    let strings: [String: Entry]

    struct Entry: Decodable {
        let localizations: [String: Localization]

        enum CodingKeys: String, CodingKey {
            case localizations
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            localizations = try container.decodeIfPresent(
                [String: Localization].self,
                forKey: .localizations
            ) ?? [:]
        }
    }

    struct Localization: Decodable {
        let stringUnit: StringUnit?
        let variations: Variations?
    }

    struct Variations: Decodable {
        let plural: [String: Variation]?
    }

    struct Variation: Decodable {
        let stringUnit: StringUnit
    }

    struct StringUnit: Decodable {
        let state: String
        let value: String
    }
}
