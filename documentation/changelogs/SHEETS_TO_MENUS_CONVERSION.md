# Sheets to Menus Conversion

## Overview
Converted all sheet presentations to menu presentations in Task Add View (TaskDetailsConfigurationView) and Task Edit View (TaskEditView) for a more streamlined user experience.

## Changes Made

### 1. TaskEditView.swift

#### Removed State Variables
- Removed `@State private var showingCatSelector: Bool = false`
- Removed `@State private var showingReminderPicker: Bool = false`

#### Removed Sheet Modifiers
- Removed `.sheet(isPresented: $showingCatSelector)` for CatSelectionSheet
- Removed `.sheet(isPresented: $showingReminderPicker)` for ReminderPickerSheet

#### Converted Cats Section to Menu
**Before:**
```swift
SimpleOptionRow(...) {
    showingCatSelector = true
}
```

**After:**
```swift
Menu {
    // "All cats" option (shown when 2+ cats exist)
    if allCats.count >= 2 {
        Button {
            assignToAllCats.toggle()
            if assignToAllCats {
                selectedCats.removeAll()
            }
        } label: {
            HStack {
                Text("Tüm kediler")
                if assignToAllCats {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
        Divider()
    }
    
    // Individual cat selection
    ForEach(allCats) { cat in
        Button {
            assignToAllCats = false
            if selectedCats.contains(cat) {
                selectedCats.remove(cat)
            } else {
                selectedCats.insert(cat)
            }
        } label: {
            HStack {
                Text(cat.name)
                if selectedCats.contains(cat) && !assignToAllCats {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
    }
} label: {
    SimpleOptionRow(...)
}
```

#### Converted Reminder Section to Menu
**Before:**
```swift
RemindersOptionRow(...) {
    if enableReminder {
        showingReminderPicker = true
    }
}
```

**After:**
```swift
Menu {
    ForEach(reminderOptions, id: \.value) { option in
        Button {
            reminderMinutes = option.value
        } label: {
            HStack {
                Text(option.label)
                if reminderMinutes == option.value {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
    }
} label: {
    RemindersOptionRow(...)
}
.disabled(!enableReminder)
```

### 2. TaskDetailsConfigurationView.swift

#### Removed State Variables
- Removed `@State private var showReminderPicker: Bool = false`

#### Removed Sheet Modifiers
- Removed `.sheet(isPresented: $showReminderPicker)` for ReminderPickerSheet

#### Converted Reminder Section to Menu
Same conversion pattern as TaskEditView, using a Menu with ForEach for reminder options.

**Note:** The Cats section in TaskDetailsConfigurationView was already using a Menu, so no changes were needed there.

## Benefits

1. **Better UX**: Menus provide immediate access to options without the modal interruption of sheets
2. **Consistency**: All selection interfaces now use the same pattern (menus)
3. **Less Code**: Removed unnecessary state variables and sheet modifiers
4. **Faster Interaction**: Users can make selections with fewer taps
5. **Native Feel**: Menus are the standard iOS pattern for option selection

## Testing

✅ Build succeeded with no errors
✅ No linter warnings or errors
✅ All functionality preserved

## Files Modified

1. `CatCareCalendar/Views/Tasks/TaskEditView.swift`
2. `CatCareCalendar/Views/Tasks/TaskDetailsConfigurationView.swift`

## Technical Notes

- The cats menu supports both "All cats" selection and individual cat selection
- The reminder menu is disabled when the reminder toggle is off
- All menu items show a checkmark indicator for selected options
- Multi-select behavior is preserved for cats (using Set operations)
- Dividers are used to separate "All cats" from individual selections

