# Reminder Toggle Fix

## Issue
The notifications toggle in `TaskDetailsConfigurationView` couldn't be toggled because the `Menu` wrapper was intercepting all tap events on the row, preventing the toggle from receiving tap gestures.

## Root Cause
The reminder section was structured as:
```swift
Menu {
    // Reminder options
} label: {
    RemindersOptionRow(
        // Row with toggle
    ) {}
}
```

The `Menu` wrapper captured all taps on the entire row, including taps on the toggle switch, making it impossible to toggle notifications on/off.

## Solution
**Removed the `Menu` wrapper and used a sheet presentation instead:**

1. **Added state variable** for controlling the reminder picker sheet:
   ```swift
   @State private var showReminderPicker: Bool = false
   ```

2. **Restructured the reminder section** to use `RemindersOptionRow` directly without Menu:
   ```swift
   RemindersOptionRow(
       icon: "bell",
       iconColor: .purple,
       title: LocalizedKey.tasksConfigNotifications.localized,
       subtitle: enableReminder ? reminderLabel : nil,
       value: nil,
       hasToggle: true,
       isToggled: $enableReminder
   ) {
       // Only show picker when reminder is enabled
       if enableReminder {
           showReminderPicker = true
       }
   }
   ```

3. **Added sheet presentation** for the reminder picker:
   ```swift
   .sheet(isPresented: $showReminderPicker) {
       ReminderPickerSheet(
           reminderMinutes: $reminderMinutes,
           reminderOptions: reminderOptions
       )
   }
   ```

## How It Works Now
1. **Toggle functionality**: Users can tap the toggle switch on the right side to enable/disable notifications
2. **Picker functionality**: When notifications are enabled, tapping the left side of the row (icon + title area) opens a sheet to select reminder timing options
3. **No interference**: The toggle and the row tap action work independently without conflict

## Benefits
- ✅ Toggle can be tapped and toggled properly
- ✅ Consistent UX with other pickers in the app (uses sheet presentation like other options)
- ✅ Clear separation between toggle and picker actions
- ✅ Follows the existing pattern used in `RemindersOptionRow` component

## Files Modified
- `CatCareCalendar/Views/Tasks/TaskDetailsConfigurationView.swift`

## Testing Notes
- Toggle should now be fully responsive to taps
- Tapping the left side of the row (when toggle is ON) should open the reminder options picker sheet
- When toggle is OFF, tapping the left side should do nothing (as per the component's design)
- The `ReminderPickerSheet` component (already existing) handles the reminder time selection

## Build Status
✅ Build successful with zero errors and warnings

