import SwiftUI
import SwiftData
import PhotosUI

struct AddCatView: View {
    
    var body: some View {
        CatFormView(mode: .add)
    }
}

// MARK: - Form Card Component
struct FormCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            content
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#if DEBUG
#Preview {
    PreviewHost(scenario: .empty) {
        AddCatView()
    }
}
#endif
