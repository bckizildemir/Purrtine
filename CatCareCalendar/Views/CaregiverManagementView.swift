import SwiftUI
import SwiftData

struct CaregiverManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var caregivers: [Caregiver]
    
    @State private var showingAddCaregiver = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack {
                if caregivers.isEmpty {
                    emptyStateView
                } else {
                    caregiverList
                }
            }
        }
        .navigationTitle(String(localized: .caregiverListTitle))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddCaregiver = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddCaregiver) {
            AddCaregiverView()
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(.caregiverListEmptyTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(.caregiverListEmptyDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button {
                showingAddCaregiver = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(.caregiverListAddFirst)
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var caregiverList: some View {
        List {
            ForEach(caregivers) { caregiver in
                CaregiverRowView(caregiver: caregiver)
            }
            .onDelete(perform: deleteCaregivers)
            .listRowBackground(Color.gray.opacity(0.1))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
    
    private func deleteCaregivers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(caregivers[index])
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Caregiver Row View
struct CaregiverRowView: View {
    let caregiver: Caregiver
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let urlString = caregiver.avatarURL, 
               !urlString.isEmpty {
                DownsampledImage(url: getAvatarURL(from: urlString), targetPointSize: 50) {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    )
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(caregiver.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(String(localized: .caregiverRowAddedOn(caregiver.createdAt.formatted(date: .abbreviated, time: .omitted))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !caregiver.completions.isEmpty {
                    Text(String(localized: .caregiverRowCompletedCount(Int32(caregiver.completions.count))))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
    
    private func getAvatarURL(from fileName: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let avatarsDirectory = documentsPath.appendingPathComponent("CaregiverAvatars")
        return avatarsDirectory.appendingPathComponent(fileName)
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    PreviewHost(scenario: .standard) {
        NavigationStack {
            CaregiverManagementView()
        }
    }
} 
#endif
