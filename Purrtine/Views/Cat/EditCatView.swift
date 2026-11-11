import SwiftUI
import SwiftData
import PhotosUI
import Foundation

struct EditCatView: View {
    let cat: Cat
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        CatFormView(mode: .edit(cat: cat), onDelete: onDelete)
    }
}

#if DEBUG
#Preview {
    PreviewHost(scenario: .standard) {
        if let cat = PreviewData.firstCat() {
            EditCatView(cat: cat)
        }
    }
} 
#endif
