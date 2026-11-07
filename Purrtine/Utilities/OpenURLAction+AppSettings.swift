import SwiftUI
import UIKit

extension OpenURLAction {
    /// Opens this app's page in the iOS Settings app.
    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        self(settingsURL)
    }
}
