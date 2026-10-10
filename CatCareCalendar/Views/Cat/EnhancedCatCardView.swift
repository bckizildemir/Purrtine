import SwiftUI
import SwiftData

struct EnhancedCatCardView: View {
    let cat: Cat
    var variant: CatCardVariant = .gallery
    @Environment(\.modelContext) private var modelContext
    @Environment(\.haptics) private var haptics
    @Environment(\.careTaskWriter) private var careTaskWriter
    @Environment(\.reportCatDeletionFailure) private var reportCatDeletionFailure
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var showingTaskAdd = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Photo Section
            photoSection
            
            // Info Section
            infoSection
        }
        .padding(16)
        .frame(width: variant.size.width, height: variant.size.height)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(variant.background)
                .shadow(color: .black.opacity(0.1), radius: variant.shadowRadius, x: 0, y: 4)
        )
        .contextMenu {
            contextMenuItems
        }
        .sheet(isPresented: $showingEditView) {
            EditCatView(cat: cat)
        }
        .sheet(isPresented: $showingTaskAdd) {
            TaskAddView(template: nil, preselectedCat: cat)
        }
        .alert(String(localized: .catEditDeleteConfirmationTitle), isPresented: $showingDeleteAlert) {
            Button(String(localized: .actionCancel), role: .cancel) { }
            Button(String(localized: .actionDelete), role: .destructive) {
                deleteCat()
            }
        } message: {
            // Guarded on `modelContext`: SwiftUI can
            // re-evaluate this closure after the delete has committed, and reading a relationship
            // on an invalidated `@Model` traps (seen on iOS 18.5 in #19).
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
                    Text(.catCardDeleteConfirmation(cat.name))
                }
            }
        }
        .onAppear {
            #if DEBUG
            print("[CatCard] Appeared cat '\\(cat.name)' stored age: \(String(describing: cat.age)) displayText: \(cat.ageDisplayText)")
            #endif
        }
    }
    
    // MARK: - Photo Section
    @ViewBuilder
    private var photoSection: some View {
        let diameter = variant.photoDiameter
        ZStack {
            // Background circle
            Circle()
                .fill(.quaternary)
                .frame(width: diameter, height: diameter)
            
            if cat.hasPhoto {
                DownsampledImage(url: catPhotoURL, targetPointSize: diameter) {
                    defaultCatImage
                }
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
            } else {
                defaultCatImage
            }
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
    private var defaultCatImage: some View {
        let diameter = variant.photoDiameter
        ZStack {
            Circle()
                .fill(.quaternary)
            
            Image(systemName: "pawprint.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: diameter, height: diameter)
    }
    
    
    // MARK: - Info Section
    @ViewBuilder
    private var infoSection: some View {
        VStack(spacing: 6) {
            // Cat Name
            Text(cat.name)
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Age and Gender
            HStack(spacing: 8) {
                if let age = cat.age, age > 0 {
                    Label(cat.ageDisplayText, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack {
                Label(cat.gender.displayName, systemImage: genderIcon)
                    .font(.caption)
                    .foregroundStyle(
                        cat.gender == .male ? .teal :
                        cat.gender == .female ? .pink :
                        .secondary
                    )
            }
            .lineLimit(1)
        }
    }
    

    // MARK: - Context Menu
    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: {
            showingEditView = true
        }) {
            Label(String(localized: .catCardEdit), systemImage: "pencil")
        }
        
        Button(action: {
            showingTaskAdd = true
        }) {
            Label(String(localized: .catDetailAddTask), systemImage: "plus.circle")
        }
        
        Button(action: {
            duplicateCat()
        }) {
            Label(String(localized: .catCardDuplicate), systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Button(role: .destructive, action: {
            showingDeleteAlert = true
        }) {
            Label(String(localized: .catCardDelete), systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    private func duplicateCat() {
        let duplicatedCat = Cat(
            name: "\(cat.name)" + String(localized: .catCardCopySuffix),
            age: cat.age,
            gender: cat.gender,
            breed: cat.breed,
            weight: cat.weight,
            weightUnit: cat.weightUnit,
            medicalNotes: cat.medicalNotes,
            medicalConditions: cat.medicalConditions
        )
        
        modelContext.insert(duplicatedCat)
        
        do {
            try modelContext.save()
            haptics.impact(.light)
        } catch {
            print("Error duplicating cat: \(error)")
        }
    }
    
    /// The cat is gone either way (#19); a failure goes to `CatsTabView`, which shows the note,
    /// because this card leaves the grid with the cat.
    private func deleteCat() {
        let catName = cat.name
        Task {
            do {
                try await CatDeletionService(taskWriter: careTaskWriter).delete(cat, from: modelContext)
                haptics.impact(.medium)
            } catch {
                if let failure = CatDeletionFailure(error: error, catName: catName) {
                    haptics.notify(.error)
                    reportCatDeletionFailure(failure)
                } else {
                    haptics.impact(.medium)
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    private var genderIcon: String {
        switch cat.gender {
        case .male: return "cat.fill"
        case .female: return "cat.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

#Preview {
    let sampleCat = Cat(
        name: "Whiskers",
        age: 24, // 2 years
        gender: .male,
        breed: "Persian"
    )
    
    EnhancedCatCardView(cat: sampleCat)
        .padding()
        .background(Color(.systemGroupedBackground))
} 
