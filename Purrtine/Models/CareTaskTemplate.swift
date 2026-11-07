import Foundation

// MARK: - CareTask Template System
struct CareTaskTemplate: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Hashable {
        case morningFeeding
        case eveningFeeding
        case freeFeedingCheck
        case specialDiet
        case freshWater
        case waterFountainClean
        case medication
        case vitamin
        case brushing
        case nailTrim
        case bath
        case toothBrushing
        case weightCheck
        case temperatureCheck
        case vetAppointment
        case vaccination
        case playTime
        case interactivePlay
        case litterCleaning
        case litterChange
        case environmentCheck
    }
    
    let kind: Kind
    let titleKey: LocalizedStringResource
    let descriptionKey: LocalizedStringResource
    let category: CareTaskCategory
    let iconName: String
    let priority: CareTaskPriority
    let defaultFrequency: CareTaskFrequency
    let defaultReminderMinutes: Int?
    let suggestedTimes: [CareTaskTime] // Suggested time slots
    let customFields: [CareTaskCustomField] // Additional fields for this template
    let tipsKey: LocalizedStringResource? // Helpful tips for the user

    var id: Kind { kind }

    init(
        kind: Kind,
        titleKey: LocalizedStringResource,
        descriptionKey: LocalizedStringResource,
        category: CareTaskCategory,
        iconName: String,
        priority: CareTaskPriority = .medium,
        defaultFrequency: CareTaskFrequency = .daily,
        defaultReminderMinutes: Int? = nil,
        suggestedTimes: [CareTaskTime] = [],
        customFields: [CareTaskCustomField] = [],
        tipsKey: LocalizedStringResource? = nil
    ) {
        self.kind = kind
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.category = category
        self.iconName = iconName
        self.priority = priority
        self.defaultFrequency = defaultFrequency
        self.defaultReminderMinutes = defaultReminderMinutes
        self.suggestedTimes = suggestedTimes
        self.customFields = customFields
        self.tipsKey = tipsKey
    }

    var title: String {
        String(localized: titleKey)
    }

    var description: String {
        String(localized: descriptionKey)
    }

    var tips: String? {
        tipsKey.map { String(localized: $0) }
    }

    // LocalizedStringResource is not Hashable; `kind` uniquely identifies a template definition.
    func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
    }
}

// MARK: - CareTask Time
struct CareTaskTime: Identifiable, Hashable {
    let id = UUID()
    let nameKey: LocalizedStringResource
    let hour: Int
    let minute: Int

    init(nameKey: LocalizedStringResource, hour: Int, minute: Int = 0) {
        self.nameKey = nameKey
        self.hour = hour
        self.minute = minute
    }

    var name: String {
        String(localized: nameKey)
    }
    
    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var date: Date {
        let calendar = Calendar.current
        let components = DateComponents(hour: hour, minute: minute)
        return calendar.date(from: components) ?? Date()
    }

    // LocalizedStringResource is not Hashable; `id` is unique per instance.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - CareTask Custom Field
struct CareTaskCustomField: Identifiable, Hashable {
    let id = UUID()
    let key: String
    let nameKey: LocalizedStringResource
    let type: FieldType
    let isRequired: Bool
    let placeholderKey: LocalizedStringResource
    let optionKeys: [LocalizedStringResource]? // For picker types

    enum FieldType {
        case text
        case number
        case picker
        case toggle
        case multilineText
    }

    init(
        key: String,
        nameKey: LocalizedStringResource,
        type: FieldType,
        isRequired: Bool,
        placeholderKey: LocalizedStringResource,
        optionKeys: [LocalizedStringResource]? = nil
    ) {
        self.key = key
        self.nameKey = nameKey
        self.type = type
        self.isRequired = isRequired
        self.placeholderKey = placeholderKey
        self.optionKeys = optionKeys
    }

    var name: String {
        String(localized: nameKey)
    }

    var placeholder: String {
        String(localized: placeholderKey)
    }

    var options: [String]? {
        optionKeys?.map { String(localized: $0) }
    }

    // LocalizedStringResource is not Hashable; `id` is unique per instance.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Template Categories
/// Holds no stored state: every member is a computed template list, so the
/// shared instance is safe to read from any isolation.
final class CareTaskTemplateManager: Sendable {
    static let shared = CareTaskTemplateManager()
    
    private init() {}
    
    // MARK: - Pre-built Templates
    var allTemplates: [CareTaskTemplate] {
        return [
            // MARK: - Feeding Templates
            morningFeedingTemplate,
            eveningFeedingTemplate,
            freeFeedingCheckTemplate,
            specialDietTemplate,
            
            // MARK: - Water Templates
            freshWaterTemplate,
            waterFountainCleanTemplate,
            
            // MARK: - Medication Templates
            medicationTemplate,
            vitaminTemplate,
            
            // MARK: - Grooming Templates
            brushingTemplate,
            nailTrimTemplate,
            bathTemplate,
            toothBrushingTemplate,
            
            // MARK: - Health Templates
            weightCheckTemplate,
            temperatureCheckTemplate,
            vetAppointmentTemplate,
            vaccinationTemplate,
            
            // MARK: - Exercise Templates
            playTimeTemplate,
            interactivePlayTemplate,
            
            // MARK: - Litter Templates
            litterCleaningTemplate,
            litterChangeTemplate,
            
            // MARK: - General Templates
            environmentCheckTemplate
        ]
    }
    
    // MARK: - Feeding Templates
    private var morningFeedingTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .morningFeeding,
            titleKey: .templateMorningFeedingTitle,
            descriptionKey: .templateMorningFeedingDescription,
            category: .feeding,
            iconName: "fork.knife",
            priority: .high,
            defaultFrequency: .daily,
            suggestedTimes: [
                CareTaskTime(nameKey: .templateTimeEarlyMorning, hour: 7),
                CareTaskTime(nameKey: .templateTimeMorning, hour: 8),
                CareTaskTime(nameKey: .templateTimeLateMorning, hour: 9)
            ],
            customFields: [
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.morningFeeding.feedingFieldKey(.portion),
                    nameKey: .templateMorningFeedingFieldPortionName,
                    type: .text,
                    isRequired: false,
                    placeholderKey: .templateMorningFeedingFieldPortionPlaceholder
                ),
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.morningFeeding.feedingFieldKey(.foodType),
                    nameKey: .templateMorningFeedingFieldFoodTypeName,
                    type: .picker,
                    isRequired: false,
                    placeholderKey: .templateMorningFeedingFieldFoodTypePlaceholder,
                    optionKeys: [
                        .templateFieldOptionDryFood,
                        .templateFieldOptionWetFood,
                        .templateFieldOptionMixedFood
                    ]
                )
            ],
            tipsKey: .templateMorningFeedingTips
        )
    }
    
    private var eveningFeedingTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .eveningFeeding,
            titleKey: .templateEveningFeedingTitle,
            descriptionKey: .templateEveningFeedingDescription,
            category: .feeding,
            iconName: "fork.knife",
            priority: .high,
            defaultFrequency: .daily,
            suggestedTimes: [
                CareTaskTime(nameKey: .templateTimeEarlyEvening, hour: 17),
                CareTaskTime(nameKey: .templateTimeEvening, hour: 18),
                CareTaskTime(nameKey: .templateTimeLateEvening, hour: 19)
            ],
            customFields: [
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.eveningFeeding.feedingFieldKey(.portion),
                    nameKey: .templateEveningFeedingFieldPortionName,
                    type: .text,
                    isRequired: false,
                    placeholderKey: .templateEveningFeedingFieldPortionPlaceholder
                ),
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.eveningFeeding.feedingFieldKey(.foodType),
                    nameKey: .templateEveningFeedingFieldFoodTypeName,
                    type: .picker,
                    isRequired: false,
                    placeholderKey: .templateEveningFeedingFieldFoodTypePlaceholder,
                    optionKeys: [
                        .templateFieldOptionDryFood,
                        .templateFieldOptionWetFood,
                        .templateFieldOptionMixedFood
                    ]
                )
            ],
            tipsKey: .templateEveningFeedingTips
        )
    }
    
    private var freeFeedingCheckTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .freeFeedingCheck,
            titleKey: .templateFreeFeedingTitle,
            descriptionKey: .templateFreeFeedingDescription,
            category: .feeding,
            iconName: "fork.knife",
            priority: .medium,
            defaultFrequency: .daily,
            defaultReminderMinutes: nil,
            suggestedTimes: [
                CareTaskTime(nameKey: .templateTimeMorning, hour: 8),
                CareTaskTime(nameKey: .templateTimeEvening, hour: 18)
            ],
            tipsKey: .templateFreeFeedingTips
        )
    }
    
    private var specialDietTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .specialDiet,
            titleKey: .templateSpecialDietTitle,
            descriptionKey: .templateSpecialDietDescription,
            category: .feeding,
            iconName: "medical.thermometer",
            priority: .urgent,
            defaultFrequency: .daily,
            customFields: [
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.specialDiet.fieldKey("dietType"),
                    nameKey: .templateSpecialDietFieldDietTypeName,
                    type: .text,
                    isRequired: true,
                    placeholderKey: .templateSpecialDietFieldDietTypePlaceholder
                ),
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.specialDiet.fieldKey("amount"),
                    nameKey: .templateSpecialDietFieldAmountName,
                    type: .text,
                    isRequired: true,
                    placeholderKey: .templateSpecialDietFieldAmountPlaceholder
                )
            ],
            tipsKey: .templateSpecialDietTips
        )
    }
    
    
    
    // MARK: - Water Templates
    private var freshWaterTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .freshWater,
            titleKey: .templateFreshWaterTitle,
            descriptionKey: .templateFreshWaterDescription,
            category: .water,
            iconName: "drop.fill",
            priority: .medium,
            defaultFrequency: .daily,
            tipsKey: .templateFreshWaterTips
        )
    }
    private var waterFountainCleanTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .waterFountainClean,
            titleKey: .templateWaterFountainCleanTitle,
            descriptionKey: .templateWaterFountainCleanDescription,
            category: .water,
            iconName: "drop.halffull",
            priority: .medium,
            defaultFrequency: .weekly,
            tipsKey: .templateWaterFountainCleanTips
        )
    }
    
    
    
    // MARK: - Medication Templates
    private var medicationTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .medication,
            titleKey: .templateMedicationTitle,
            descriptionKey: .templateMedicationDescription,
            category: .medication,
            iconName: "pills.fill",
            priority: .urgent,
            defaultFrequency: .daily,
            customFields: [
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.medication.fieldKey("medicineName"),
                    nameKey: .templateMedicationFieldName,
                    type: .text,
                    isRequired: true,
                    placeholderKey: .templateMedicationFieldNamePlaceholder
                ),
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.medication.fieldKey("dosage"),
                    nameKey: .templateMedicationFieldDosage,
                    type: .text,
                    isRequired: true,
                    placeholderKey: .templateMedicationFieldDosagePlaceholder
                ),
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.medication.fieldKey("withFood"),
                    nameKey: .templateMedicationFieldWithFood,
                    type: .toggle,
                    isRequired: false,
                    placeholderKey: .templateMedicationFieldWithFoodPlaceholder
                ),
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.medication.fieldKey("notes"),
                    nameKey: .templateMedicationFieldNotes,
                    type: .multilineText,
                    isRequired: false,
                    placeholderKey: .templateMedicationFieldNotesPlaceholder
                )
            ],
            tipsKey: .templateMedicationTips
        )
    }
    
    private var vitaminTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .vitamin,
            titleKey: .templateVitaminTitle,
            descriptionKey: .templateVitaminDescription,
            category: .medication,
            iconName: "pills",
            priority: .medium,
            defaultFrequency: .daily,
            customFields: [
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.vitamin.fieldKey("supplementType"),
                    nameKey: .templateVitaminFieldSupplementTypeName,
                    type: .picker,
                    isRequired: false,
                    placeholderKey: .templateVitaminFieldSupplementTypePlaceholder,
                    optionKeys: [
                        .templateFieldOptionMultivitamin,
                        .templateFieldOptionOmega3,
                        .templateFieldOptionProbiotic,
                        .templateFieldOptionTaurine
                    ]
                )
            ],
            tipsKey: .templateVitaminTips
        )
    }
    
    // MARK: - Grooming Templates
    private var brushingTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .brushing,
            titleKey: .templateBrushingTitle,
            descriptionKey: .templateBrushingDescription,
            category: .grooming,
            iconName: "comb",
            priority: .medium,
            defaultFrequency: .daily,
            defaultReminderMinutes: nil,
            suggestedTimes: [
                CareTaskTime(nameKey: .templateTimeMorning, hour: 9),
                CareTaskTime(nameKey: .templateTimeEvening, hour: 20)
            ],
            tipsKey: .templateBrushingTips
        )
    }
    
    private var nailTrimTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .nailTrim,
            titleKey: .templateNailTrimTitle,
            descriptionKey: .templateNailTrimDescription,
            category: .grooming,
            iconName: "scissors",
            priority: .medium,
            defaultFrequency: .biweekly,
            tipsKey: .templateNailTrimTips
        )
    }
    
    private var bathTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .bath,
            titleKey: .templateBathTitle,
            descriptionKey: .templateBathDescription,
            category: .grooming,
            iconName: "bathtub.fill",
            priority: .low,
            defaultFrequency: .monthly,
            tipsKey: .templateBathTips
        )
    }
    
    private var toothBrushingTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .toothBrushing,
            titleKey: .templateToothBrushingTitle,
            descriptionKey: .templateToothBrushingDescription,
            category: .grooming,
            iconName: "bubbles.and.sparkles.fill",
            priority: .medium,
            defaultFrequency: .weekly,
            tipsKey: .templateToothBrushingTips
        )
    }
    
    // MARK: - Health Templates
    private var weightCheckTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .weightCheck,
            titleKey: .templateWeightCheckTitle,
            descriptionKey: .templateWeightCheckDescription,
            category: .health,
            iconName: "scalemass.fill",
            priority: .medium,
            defaultFrequency: .weekly,
            customFields: [
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.weightCheck.fieldKey("weight"),
                    nameKey: .templateWeightCheckFieldWeightName,
                    type: .number,
                    isRequired: false,
                    placeholderKey: .templateWeightCheckFieldWeightPlaceholder
                )
            ],
            tipsKey: .templateWeightCheckTips
        )
    }
    
    private var temperatureCheckTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .temperatureCheck,
            titleKey: .templateTemperatureCheckTitle,
            descriptionKey: .templateTemperatureCheckDescription,
            category: .health,
            iconName: "thermometer",
            priority: .high,
            defaultFrequency: .once,
            customFields: [
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.temperatureCheck.fieldKey("temperature"),
                    nameKey: .templateTemperatureCheckFieldTemperatureName,
                    type: .number,
                    isRequired: false,
                    placeholderKey: .templateTemperatureCheckFieldTemperaturePlaceholder
                )
            ],
            tipsKey: .templateTemperatureCheckTips
        )
    }
    
    private var vetAppointmentTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .vetAppointment,
            titleKey: .templateVetAppointmentTitle,
            descriptionKey: .templateVetAppointmentDescription,
            category: .vet,
            iconName: "stethoscope.circle.fill",
            priority: .high,
            defaultFrequency: .once,
            customFields: [
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.vetAppointment.fieldKey("clinic"),
                    nameKey: .templateVetAppointmentFieldClinicName,
                    type: .text,
                    isRequired: false,
                    placeholderKey: .templateVetAppointmentFieldClinicPlaceholder
                ),
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.vetAppointment.fieldKey("reason"),
                    nameKey: .templateVetAppointmentFieldReasonName,
                    type: .multilineText,
                    isRequired: false,
                    placeholderKey: .templateVetAppointmentFieldReasonPlaceholder
                )
            ],
            tipsKey: .templateVetAppointmentTips
        )
    }

    private var vaccinationTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .vaccination,
            titleKey: .templateVaccinationTitle,
            descriptionKey: .templateVaccinationDescription,
            category: .vet,
            iconName: "syringe.fill",
            priority: .high,
            defaultFrequency: .once,
            customFields: [
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.vaccination.fieldKey("clinic"),
                    nameKey: .templateVaccinationFieldClinicName,
                    type: .text,
                    isRequired: false,
                    placeholderKey: .templateVaccinationFieldClinicPlaceholder
                )
            ],
            tipsKey: .templateVaccinationTips
        )
    }
    
    // MARK: - Exercise Templates
    private var playTimeTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .playTime,
            titleKey: .templatePlayTimeTitle,
            descriptionKey: .templatePlayTimeDescription,
            category: .exercise,
            iconName: "gamecontroller.fill",
            priority: .medium,
            defaultFrequency: .daily,
            defaultReminderMinutes: nil,
            suggestedTimes: [
                CareTaskTime(nameKey: .templateTimeMorning, hour: 10),
                CareTaskTime(nameKey: .templateTimeEvening, hour: 19)
            ],
            customFields: [
                CareTaskCustomField(
                    key: CareTaskTemplate.Kind.playTime.fieldKey("duration"),
                    nameKey: .templatePlayTimeFieldDurationName,
                    type: .picker,
                    isRequired: false,
                    placeholderKey: .templatePlayTimeFieldDurationPlaceholder,
                    optionKeys: [
                        .templateFieldOptionDuration5,
                        .templateFieldOptionDuration10,
                        .templateFieldOptionDuration15,
                        .templateFieldOptionDuration20
                    ]
                )
            ],
            tipsKey: .templatePlayTimeTips
        )
    }
    
    private var interactivePlayTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .interactivePlay,
            titleKey: .templateInteractivePlayTitle,
            descriptionKey: .templateInteractivePlayDescription,
            category: .exercise,
            iconName: "puzzlepiece.fill",
            priority: .medium,
            defaultFrequency: .weekly,
            tipsKey: .templateInteractivePlayTips
        )
    }
    
    // MARK: - Litter Templates
    private var litterCleaningTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .litterCleaning,
            titleKey: .templateLitterCleaningTitle,
            descriptionKey: .templateLitterCleaningDescription,
            category: .litter,
            iconName: "tray.and.arrow.up.fill",
            priority: .high,
            defaultFrequency: .daily,
            defaultReminderMinutes: nil,
            suggestedTimes: [
                CareTaskTime(nameKey: .templateTimeMorning, hour: 8),
                CareTaskTime(nameKey: .templateTimeEvening, hour: 20)
            ],
            tipsKey: .templateLitterCleaningTips
        )
    }
    
    private var litterChangeTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .litterChange,
            titleKey: .templateLitterChangeTitle,
            descriptionKey: .templateLitterChangeDescription,
            category: .litter,
            iconName: "arrow.up.trash.fill",
            priority: .medium,
            defaultFrequency: .weekly,
            tipsKey: .templateLitterChangeTips
        )
    }
    
    // MARK: - General Templates
    
    private var environmentCheckTemplate: CareTaskTemplate {
        CareTaskTemplate(
            kind: .environmentCheck,
            titleKey: .templateEnvironmentCheckTitle,
            descriptionKey: .templateEnvironmentCheckDescription,
            category: .general,
            iconName: "shield.checkered",
            priority: .low,
            defaultFrequency: .weekly,
            tipsKey: .templateEnvironmentCheckTips
        )
    }
    
    // MARK: - Template Helpers
    func templates(for category: CareTaskCategory) -> [CareTaskTemplate] {
        return allTemplates.filter { $0.category == category }
    }
    
    func popularTemplates() -> [CareTaskTemplate] {
        return [
            morningFeedingTemplate,
            eveningFeedingTemplate,
            freshWaterTemplate,
            litterCleaningTemplate,
            playTimeTemplate,
            brushingTemplate,
        ]
    }
    
}

private extension CareTaskTemplate.Kind {
    func fieldKey(_ identifier: String) -> String {
        "\(rawValue).field.\(identifier)"
    }
}

extension CareTaskTemplate.Kind {
    func feedingFieldKey(_ kind: FeedingFieldKind) -> String {
        fieldKey(kind.rawValue)
    }
}
