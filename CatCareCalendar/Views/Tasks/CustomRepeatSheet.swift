import SwiftUI

struct CustomRepeatSheet: View {
    @Binding var configuration: RepeatConfiguration
    let onSave: (RepeatConfiguration) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isIntervalPickerVisible = false
    @State private var initialConfiguration: RepeatConfiguration?

    private let intervalRange = Array(1...99)

    private var hasUnsavedChanges: Bool {
        guard let initialConfiguration else { return false }
        return configuration != initialConfiguration
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    repeatCard
                    
                    if configuration.unit == .week {
                        weekdaySelector
                    }
                    
                    summaryLabel
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(String(localized: .repeatCustomTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetDismissButton(hasUnsavedChanges: hasUnsavedChanges, onDismiss: dismiss.callAsFunction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirmButton {
                        onSave(configuration)
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onAppear {
            if initialConfiguration == nil {
                initialConfiguration = configuration
            }
        }
    }
    
    private var repeatCard: some View {
        VStack(spacing: 0) {
            Menu {
                ForEach(RepeatConfiguration.Unit.allCases, id: \.self) { unit in
                    Button {
                        configuration.unit = unit
                        if unit != .week {
                            configuration.selectedWeekdays.removeAll()
                        }
                    } label: {
                        HStack {
                            Text(unit.localizedName)
                            if configuration.unit == unit {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                rowLabel(
                    title: String(localized: .repeatCustomFrequency),
                    value: configuration.unit.localizedName,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            
            Divider()
                .padding(.leading, 16)
            
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isIntervalPickerVisible.toggle()
                }
            } label: {
                rowLabel(
                    title: String(localized: .repeatCustomEvery),
                    value: intervalLabel,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            
            if isIntervalPickerVisible {
                Picker(String(localized: .repeatCustomEvery), selection: intervalBinding) {
                    ForEach(intervalRange, id: \.self) { value in
                        Text(value, format: .number)
                            .tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .fixedSize()
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var weekdaySelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.repeatCustomWeekdays)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            WeekdayPicker(selectedDays: $configuration.selectedWeekdays)
                .padding(.horizontal, 4)
        }
    }
    
    private var summaryLabel: some View {
        Text(
            String(localized: .repeatCustomSummaryDescription(configuration.localizedSummary()))
        )
        .font(.footnote)
        .foregroundColor(.secondary)
    }
    
    private var intervalLabel: String {
        let unitText = configuration.interval == 1 ? configuration.unit.localizedSingular : configuration.unit.localizedPlural
        return "\(configuration.interval) \(unitText)"
    }
    
    private var intervalBinding: Binding<Int> {
        Binding(
            get: { configuration.interval },
            set: { newValue in
                configuration.interval = max(1, newValue)
            }
        )
    }
    
    private func rowLabel(title: String, value: String, showsChevron: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
    }
}

#Preview("Custom Repeat") {
    @Previewable @State var configuration = RepeatConfiguration(
        unit: .week,
        interval: 1,
        selectedWeekdays: [1, 3, 5]
    )

    CustomRepeatSheet(configuration: $configuration) { _ in }
}

private struct WeekdayPicker: View {
    @Binding var selectedDays: Set<Int>
    
    private var calendar: Calendar { Calendar.current }
    
    private var daySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        // Convert to 0-indexed (starting Sunday) to mirror stored values
        return symbols
    }
    
    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(daySymbols.indices, id: \.self) { index in
                let dayIndex = index // Already 0-based with Sunday first
                let symbol = daySymbols[index]
                let isSelected = selectedDays.contains(dayIndex)
                
                Button {
                    if isSelected {
                        selectedDays.remove(dayIndex)
                    } else {
                        selectedDays.insert(dayIndex)
                    }
                } label: {
                    Text(symbol)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
