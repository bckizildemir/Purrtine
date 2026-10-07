import SwiftUI
import PhotosUI

struct FirstCatSetupView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        CatFormView(mode: .onboarding(onContinue: onContinue, onSkip: onSkip))
    }
}

#Preview {
    FirstCatSetupView(
        onContinue: { print("Continue") },
        onSkip: { print("Skip") }
    )
} 
