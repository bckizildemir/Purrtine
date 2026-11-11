#if DEBUG
import SwiftUI

// PROTOTYPE (throwaway): the category color mapping from `TaskRow.categoryColor` (private there),
// copied so the prototype calendars can draw category-colored dots.

extension CareTaskCategory {
    var prototypeTint: Color {
        switch color {
        case "systemOrange": .orange
        case "systemBlue": .blue
        case "systemRed": .red
        case "systemturquoise": Color(red: 0.25, green: 0.78, blue: 0.88)
        case "systemPink": .pink
        case "systemGreen": .green
        case "systemBrown": .brown
        case "systemPurple": .purple
        default: .gray
        }
    }
}
#endif
