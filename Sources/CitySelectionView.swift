import SwiftUI

struct CitySelectionView: View {
    @EnvironmentObject var appState: WeathervaneState
    @State private var searchText = ""
    @State private var selectedCityCodes: Set<String> = []

    let onClose: () -> Void

    init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
    }

    private var filteredCities: [City] {
        guard !searchText.isEmpty else {
            return appState.allAvailableTimezones
        }
        let search = searchText.lowercased()
        return appState.allAvailableTimezones.filter { city in
            city.displayName.lowercased().contains(search) ||
                city.code.lowercased().contains(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            searchField
            cityList
            actions
        }
        .padding(20)
        .onAppear {
            selectedCityCodes = Set(appState.selectedCities.map(\.code))
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Select Cities")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose up to \(Constants.maxSelectedCities) cities to display.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("24-hour time", isOn: $appState.use24HourTime)
                .toggleStyle(.switch)
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search cities…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var cityList: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredCities, id: \.code) { city in
                        CitySelectionRow(
                            city: city,
                            currentDate: timeline.date,
                            use24Hour: appState.use24HourTime,
                            isSelected: selectedCityCodes.contains(city.code),
                            selectionEnabled: canToggle(city)
                        ) { isSelected in
                            updateSelection(for: city, isSelected: isSelected)
                        }
                        .padding(.horizontal, 4)
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var actions: some View {
        HStack {
            Button(Constants.cancelButtonLabel) {
                onClose()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()
            selectionCount
            Spacer()

            Button(Constants.saveButtonLabel) {
                let selectedCities = appState.allAvailableTimezones.filter {
                    selectedCityCodes.contains($0.code)
                }
                appState.updateSelectedCities(selectedCities)
                onClose()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
        }
    }

    private var selectionCount: some View {
        VStack(spacing: 2) {
            Text("\(selectedCityCodes.count) cities selected")
                .font(.caption)
                .foregroundColor(.secondary)
            if selectedCityCodes.count == Constants.maxSelectedCities {
                Text("Selection limit reached")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }

    private func canToggle(_ city: City) -> Bool {
        selectedCityCodes.contains(city.code) ||
            selectedCityCodes.count < Constants.maxSelectedCities
    }

    private func updateSelection(for city: City, isSelected: Bool) {
        if isSelected {
            guard selectedCityCodes.count < Constants.maxSelectedCities else {
                return
            }
            selectedCityCodes.insert(city.code)
        } else {
            selectedCityCodes.remove(city.code)
        }
    }
}

struct CitySelectionRow: View {
    let city: City
    let currentDate: Date
    let use24Hour: Bool
    let isSelected: Bool
    let selectionEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle(!isSelected)
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .disabled(!selectionEnabled)
            .accessibilityLabel("Select \(city.displayName)")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(city.emoji) \(city.code)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    Text(city.displayName)
                        .font(.body)
                    Spacer()
                    Text(DateFormatting.formatShortTime(
                        for: city,
                        date: currentDate,
                        use24Hour: use24Hour
                    ))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                }
                Text(city.timeZoneIdentifier)
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            guard selectionEnabled else {
                return
            }
            onToggle(!isSelected)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .opacity(selectionEnabled ? 1 : 0.5)
    }
}

#Preview {
    CitySelectionView(onClose: {})
        .environmentObject(WeathervaneState())
        .frame(width: 500, height: 600)
}
