import SwiftUI
import SwiftData
import PhotosUI

struct CatDetailView: View {
    let cat: Cat
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.careTaskWriter) private var careTaskWriter
    @Environment(\.reportCatDeletionFailure) private var reportCatDeletionFailure
    @State private var showingEditView = false
    @State private var showingPhotoSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var shouldDismissAfterEditDelete = false
    @State private var deletionFailureHandoff = CatDeletionFailureHandoff()
    
    // MARK: - Computed Properties
    private var missingFieldsCount: Int {
        var count = 0
        if !cat.hasPhoto { count += 1 }
        if cat.gender == .unknown { count += 1 }
        if cat.age == nil || cat.age == 0 { count += 1 }
        if cat.weight == nil { count += 1 }
        return count
    }
    
    private var completedFieldsCount: Int {
        4 - missingFieldsCount
    }
    
    private var shouldShowProfileCard: Bool {
        missingFieldsCount >= 2
    }
    
    private var isProfileMostlyEmpty: Bool {
        cat.gender == .unknown &&
        (cat.age == nil || cat.age == 0) &&
        cat.weight == nil &&
        (cat.breed?.isEmpty ?? true) &&
        cat.medicalConditions.isEmpty &&
        (cat.medicalNotes?.isEmpty ?? true)
    }

    private var hasAdditionalInformation: Bool {
        (cat.breed?.isEmpty == false) ||
        cat.weight != nil ||
        !cat.medicalConditions.isEmpty ||
        (cat.medicalNotes?.isEmpty == false)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Avatar Header
                avatarHeader
                
                // Quick Action Chips
                if missingFieldsCount > 0 {
                    quickActionChips
                }
                
                // Profile Completion Card
                if shouldShowProfileCard && !isProfileMostlyEmpty {
                    profileCompletionCard
                }
                
                // Information Sections or Empty State
                if isProfileMostlyEmpty {
                    emptyStateView
                } else {
                    informationSections
                }
                
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: .catDetailEdit)) {
                    showingEditView = true
                }
                .accessibilityLabel(String(localized: .catDetailEdit))
                .accessibilityIdentifier("catDetail.editButton")
            }
        }
        .sheet(isPresented: $showingEditView) {
            EditCatView(cat: cat) {
                shouldDismissAfterEditDelete = true
                dismiss()
            }
        }
        .sheet(isPresented: $showingPhotoSheet) {
            PhotoSheetView(cat: cat)
                .presentationDetents([.medium, .large])
        }
        .alert(String(localized: .catEditDeleteConfirmationTitle), isPresented: $showingDeleteConfirmation) {
            Button(String(localized: .actionCancel), role: .cancel) { }
            Button(String(localized: .actionDelete), role: .destructive) {
                deleteCat()
            }
        } message: {
            deleteConfirmationMessage
        }
        .onAppear {
            deletionFailureHandoff.screenDidAppear()
        }
        .onDisappear {
            deletionFailureHandoff.screenDidLeave()
        }
        .onChange(of: showingEditView) { _, isPresented in
            guard isPresented == false, shouldDismissAfterEditDelete else { return }
            shouldDismissAfterEditDelete = false
            dismiss()
        }
    }
    
    // MARK: - Avatar Header
    @ViewBuilder
    private var avatarHeader: some View {
        VStack(spacing: 12) {
            // Round Avatar
            avatarView
                .frame(width: 140, height: 140)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(.quaternaryLabel), lineWidth: 1))
                .onTapGesture {
                    if cat.hasPhoto {
                        showingPhotoSheet = true
                    }
                }
                .accessibilityLabel(cat.hasPhoto ? String(localized: .catDetailPhotoTapToView) : String(localized: .catDetailNoPhoto))
                .accessibilityHint(cat.hasPhoto ? String(localized: .catDetailPhotoTapHint) : "")
            
            // Cat Name
            Text(cat.name)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(.top, 24)
    }
    
    @ViewBuilder
    private var avatarView: some View {
        DownsampledImage(url: catPhotoURL, targetPointSize: 140) {
            avatarPlaceholder
        }
    }

    /// Resolved on-disk URL of the cat's first photo, preferring the stored file path and
    /// falling back to a legacy absolute-string URL.
    private var catPhotoURL: URL? {
        guard cat.hasPhoto else { return nil }
        if let photoPath = cat.firstPhotoPath,
           let photoURL = PhotoManager.shared.getPhotoURL(from: photoPath) {
            return photoURL
        }
        if let urlString = cat.firstPhotoURL {
            return URL(string: urlString)
        }
        return nil
    }
    
    @ViewBuilder
    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
            
            Text(cat.name.prefix(1).uppercased())
                .font(.system(size: 60, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Quick Action Chips
    @ViewBuilder
    private var quickActionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !cat.hasPhoto {
                    ActionChip(
                        icon: "camera.fill",
                        label: String(localized: .catDetailAddPhoto),
                        action: { showingEditView = true }
                    )
                    .accessibilityLabel(String(localized: .catDetailAddPhoto))
                    .accessibilityHint(Text(.catDetailHintAddPhoto(cat.name)))
                }
                
                if cat.gender == .unknown {
                    ActionChip(
                        icon: "person.text.rectangle",
                        label: String(localized: .catDetailAddGender),
                        action: { showingEditView = true }
                    )
                    .accessibilityLabel(String(localized: .catDetailAddGender))
                    .accessibilityHint(Text(.catDetailHintAddGender(cat.name)))
                }
                
                if cat.age == nil || cat.age == 0 {
                    ActionChip(
                        icon: "calendar.badge.plus",
                        label: String(localized: .catDetailAddBirthday),
                        action: { showingEditView = true }
                    )
                    .accessibilityLabel(String(localized: .catDetailAddBirthday))
                    .accessibilityHint(Text(.catDetailHintAddBirthday(cat.name)))
                }
                
                if cat.weight == nil {
                    ActionChip(
                        icon: "scalemass",
                        label: String(localized: .catDetailAddWeight),
                        action: { showingEditView = true }
                    )
                    .accessibilityLabel(String(localized: .catDetailAddWeight))
                    .accessibilityHint(Text(.catDetailHintAddWeight(cat.name)))
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, -4)
    }
    
    // MARK: - Profile Completion Card
    @ViewBuilder
    private var profileCompletionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(.catDetailCompleteProfileTitle(cat.name))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(String(localized: .catDetailCompleteProfileProgress(Int32(completedFieldsCount), 4)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingEditView = true }) {
                    Text(.catDetailAddDetailsCta)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
                .accessibilityLabel(String(localized: .catDetailAddDetailsCta))
                .accessibilityHint(Text(.catDetailHintCompleteProfile(cat.name)))
                .accessibilityIdentifier("catDetail.completeProfileButton")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Empty State View
    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(String(localized: .catDetailEmptyStateTitle), systemImage: "pawprint.fill")
        } description: {
            Text(.catDetailEmptyStateDescription(cat.name))
        } actions: {
            Button(action: { showingEditView = true }) {
                Text(.catDetailEmptyStateAction)
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(String(localized: .catDetailEmptyStateAction))
            .accessibilityHint(Text(.catDetailHintAddDetails(cat.name)))
            .accessibilityIdentifier("catDetail.emptyStateAction")
        }
        .padding(.top, 16)
        .padding(.bottom, 40)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("catDetail.emptyState")
    }
    
    // MARK: - Information Sections
    @ViewBuilder
    private var informationSections: some View {
        VStack(spacing: 24) {
            // Basic Information Section
            basicInformationSection

            // Additional Information Section
            if hasAdditionalInformation {
                additionalInformationSection
            }
        }
    }

    // MARK: - Basic Information Section
    @ViewBuilder
    private var basicInformationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Text(.catDetailBasicSection)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // Information Rows
            VStack(spacing: 0) {
                // Name
                BasicInfoRow(label: String(localized: .catDetailNameLabel), value: cat.name)
                Divider().padding(.leading, 16)

                // Gender
                if cat.gender == .unknown {
                    ActionableInfoRow(
                        label: String(localized: .catDetailGenderLabel),
                        placeholder: String(localized: .catDetailValueAddGender),
                        action: { showingEditView = true }
                    )
                    .accessibilityLabel(String(localized: .catDetailGenderLabel))
                    .accessibilityHint(Text(.catDetailHintRowAddGender(cat.name)))
                } else {
                    BasicInfoRow(label: String(localized: .catDetailGenderLabel), value: cat.gender.displayName)
                }

                // Age
                Divider().padding(.leading, 16)
                if let age = cat.age, age > 0 {
                    BasicInfoRow(label: String(localized: .catDetailAgeLabel), value: cat.ageDisplayText)
                } else {
                    ActionableInfoRow(
                        label: String(localized: .catDetailAgeLabel),
                        placeholder: String(localized: .catDetailValueAddBirthday),
                        action: { showingEditView = true }
                    )
                    .accessibilityLabel(String(localized: .catDetailAgeLabel))
                    .accessibilityHint(Text(.catDetailHintRowAddBirthday(cat.name)))
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
        .accessibilityIdentifier("catDetail.basicInformationSection")
    }

    // MARK: - Additional Information Section
    @ViewBuilder
    private var additionalInformationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Text(.catDetailAdditionalSection)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // Information Rows
            VStack(spacing: 0) {
                // Breed
                if let breed = cat.breed, !breed.isEmpty {
                    BasicInfoRow(label: String(localized: .catDetailBreedLabel), value: breed)
                    if shouldShowAdditionalDivider() {
                        Divider().padding(.leading, 16)
                    }
                }

                // Weight
                if cat.weight != nil {
                    BasicInfoRow(label: String(localized: .catDetailWeightLabel), value: cat.weightDisplayText)
                    if !cat.medicalConditions.isEmpty || !(cat.medicalNotes?.isEmpty ?? true) {
                        Divider().padding(.leading, 16)
                    }
                } else if shouldShowWeightPlaceholder() {
                    ActionableInfoRow(
                        label: String(localized: .catDetailWeightLabel),
                        placeholder: String(localized: .catDetailValueAddWeight),
                        action: { showingEditView = true }
                    )
                    .accessibilityLabel(String(localized: .catDetailWeightLabel))
                    .accessibilityHint(Text(.catDetailHintRowAddWeight(cat.name)))
                    
                    if !cat.medicalConditions.isEmpty || !(cat.medicalNotes?.isEmpty ?? true) {
                        Divider().padding(.leading, 16)
                    }
                }

                // Medical Conditions
                if !cat.medicalConditions.isEmpty {
                    BasicInfoRow(label: String(localized: .catDetailMedicalConditionsLabel), value: cat.medicalConditions.joined(separator: ", "), isMultiline: true)
                    if let notes = cat.medicalNotes, !notes.isEmpty {
                        Divider().padding(.leading, 16)
                    }
                }

                // Medical Notes
                if let notes = cat.medicalNotes, !notes.isEmpty {
                    BasicInfoRow(label: String(localized: .catDetailNotesLabel), value: notes, isMultiline: true)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
        .accessibilityIdentifier("catDetail.additionalInformationSection")
    }
    
    private func shouldShowWeightPlaceholder() -> Bool {
        // Show weight placeholder if there's other content in additional section
        return (cat.breed != nil && !cat.breed!.isEmpty) ||
               !cat.medicalConditions.isEmpty ||
               !(cat.medicalNotes?.isEmpty ?? true)
    }

    private func shouldShowAdditionalDivider() -> Bool {
        // Show divider if there's weight, medical conditions, or notes after breed
        return cat.weight != nil || !cat.medicalConditions.isEmpty || !(cat.medicalNotes?.isEmpty ?? true)
    }
    
    /// Content for the delete-confirmation alert. Guarded on `modelContext` because SwiftUI can
    /// re-evaluate this closure during a body pass after `deleteCat()` has removed `cat` from the
    /// store, and reading a relationship on an invalidated `@Model` traps.
    @ViewBuilder
    private var deleteConfirmationMessage: some View {
        if cat.modelContext != nil {
            let tasksCount = cat.tasks.count
            if tasksCount > 0 {
                let sharedCount = cat.tasks.filter { $0.assignedCats.count > 1 }.count
                let singleCount = tasksCount - sharedCount

                if sharedCount > 0 {
                    Text(.catDeleteWithTasksAndSharedWarning(cat.name, Int32(singleCount), Int32(sharedCount)))
                } else {
                    Text(.catDeleteWithTasksWarning(cat.name, Int32(singleCount)))
                }
            } else {
                Text(.catEditDeleteConfirmationMessage(cat.name))
            }
        }
    }

    // MARK: - Helper Methods
    /// A failed delete still leaves this screen: the cat is gone either way (#19), and
    /// `CatsTabView` shows the note once this screen has left, so the alert never races the
    /// confirmation alert's dismissal. The screen can leave before the delete finishes, because its
    /// link leaves the cats grid with the cat (#31).
    private func deleteCat() {
        let catName = cat.name
        let deletionFailureHandoff = deletionFailureHandoff
        let reportCatDeletionFailure = reportCatDeletionFailure
        Task {
            var failure: CatDeletionFailure?
            do {
                try await CatDeletionService(taskWriter: careTaskWriter).delete(cat, from: modelContext)
            } catch {
                failure = CatDeletionFailure(error: error, catName: catName)
            }
            deletionFailureHandoff.deleteDidFinish(with: failure, reporting: reportCatDeletionFailure)
            dismiss()
        }
    }
}

// MARK: - Basic Info Row
struct BasicInfoRow: View {
    let label: String
    let value: String
    var isMultiline: Bool = false
    
    var body: some View {
        HStack(alignment: isMultiline ? .top : .center, spacing: 12) {
            Text(label)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.body)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Actionable Info Row
struct ActionableInfoRow: View {
    let label: String
    let placeholder: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 4) {
                    Text(placeholder)
                        .foregroundStyle(.blue)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Chip
struct ActionChip: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.medium))
                
                Text(label)
                    .font(.subheadline)
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.05))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Photo Sheet View
struct PhotoSheetView: View {
    let cat: Cat
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
        ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if cat.hasPhoto {
                        Group {
                        if let photoPath = cat.firstPhotoPath,
                           let photoURL = PhotoManager.shared.getPhotoURL(from: photoPath) {
                                AsyncImage(url: photoURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    ProgressView()
                                }
                        } else if let photoURL = cat.firstPhotoURL {
                            AsyncImage(url: URL(string: photoURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    ProgressView()
                            }
                        } else {
                            photoNotAvailable
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    photoNotAvailable
                }
            }
            .navigationTitle(cat.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetDismissButton {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var photoNotAvailable: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(.catDetailPhotoNotFound)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
#Preview("Complete Profile") {
    PreviewHost(scenario: .longContent) {
        if let cat = PreviewData.firstCat(in: .longContent) {
            NavigationStack {
                CatDetailView(cat: cat)
            }
        }
    }
} 
#endif
