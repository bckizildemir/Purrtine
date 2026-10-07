import SwiftUI
import SwiftData

struct CatsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cats: [Cat]
    @State private var showingAddCat = false
    @State private var searchText = ""
    @State private var isSearchPresented = false

    @State private var viewWidth: CGFloat = 0

    // Narrow-phone tweaks (e.g., iPhone 12 mini – 375pt width)
    private var isNarrowPhone: Bool { viewWidth > 0 && viewWidth <= 375 }
    private var gridSpacing: CGFloat { isNarrowPhone ? 12 : 16 }
    private var horizontalPadding: CGFloat { isNarrowPhone ? 16 : 20 }
    
    // Enhanced grid columns based on device orientation
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: CatCardVariant.gallery.size.width), spacing: gridSpacing)]
    }

    // Filtered cats based on search
    private var filteredCats: [Cat] {
        if searchText.isEmpty {
            return cats.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            return cats.filter { cat in
                cat.name.localizedCaseInsensitiveCompare(searchText) != .orderedSame &&
                cat.name.localizedStandardContains(searchText) ||
                (cat.breed?.localizedStandardContains(searchText) ?? false)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if cats.isEmpty {
                // Enhanced Empty State
                emptyStateView
            } else {
                // Main Content
                mainContentView
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewWidth = $0 }
        .navigationChromeTitle(
            semanticTitle: String(localized: .catsTitle),
            visualTitle: Text(.catsTitle),
            usesEditorToolbarRole: false
        )
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !cats.isEmpty {
                    // Search button (shows when 5+ cats)
                    if cats.count >= 5 {
                        Button(action: { isSearchPresented.toggle() }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // Add button
                Button(action: { showingAddCat = true }) {
                    Image(systemName: "plus")
                        .foregroundStyle(.blue)
                }
                .accessibilityIdentifier("cats.addButton")
            }
        }
        .searchable(
            text: $searchText,
            isPresented: $isSearchPresented,
            prompt: String(localized: .catsSearchPlaceholder)
        )
        .sheet(isPresented: $showingAddCat) {
            AddCatView()
        }
        .onAppear {
            sanitizeInvalidAges()
        }
        .accessibilityIdentifier("cats.view")
    }
    
    // MARK: - Main Content View
    @ViewBuilder
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Search results info
            if !searchText.isEmpty {
                searchResultsHeader
            }

            // Cats Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(filteredCats) { cat in
                        catCardView(for: cat)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
            .refreshable {
                // Refresh logic could be added here
            }
        }
    }

    // MARK: - Data Sanitization
    private func sanitizeInvalidAges() {
        var didModify = false
        for cat in cats {
            if let age = cat.age, age <= 0 {
                cat.age = nil
                didModify = true
            }
        }
        if didModify {
            do { try modelContext.save() } catch { print("Failed to sanitize ages: \(error)") }
        }
    }

    // MARK: - Cat Card View
    @ViewBuilder
    private func catCardView(for cat: Cat) -> some View {
        NavigationLink(destination: CatDetailView(cat: cat)) {
            EnhancedCatCardView(cat: cat)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cats.card.\(cat.name)")
    }
    
    // MARK: - Search Results Header
    @ViewBuilder
    private var searchResultsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(.catsSearchResults)
                    .font(.headline)

                Text(.catsFoundCount(Int32(filteredCats.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(String(localized: .actionClear)) {
                searchText = ""
                isSearchPresented = false
            }
            .font(.caption)
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
    
    // MARK: - Empty State View
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            // Illustration
            VStack(spacing: 16) {
                Image(systemName: "cat.circle.fill")
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 8) {
                    Text(.catsNoCatsTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(.catsNoCatsDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            // Add First Cat Button
            Button(action: { showingAddCat = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text(.catsAddFirstCat)
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(height: 50)
                .frame(maxWidth: 280)
                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("cats.empty.addButton")
        }
        .padding(.horizontal, 40)
    }
}

#if DEBUG
#Preview {
    PreviewHost(scenario: .standard) {
        NavigationStack {
            CatsTabView()
        }
    }
} 
#endif
