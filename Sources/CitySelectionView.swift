import SwiftUI

struct CitySelectionView: View {
    @EnvironmentObject var appState: WeathervaneState
    @State private var searchText = ""
    @State private var selectedCityCodes: Set<String> = []
    let onClose: () -> Void
    
    init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
    }
    
    var filteredCities: [City] {
        if searchText.isEmpty {
            return appState.allAvailableTimezones
        } else {
            let searchLower = searchText.lowercased()
            return appState.allAvailableTimezones.filter { city in
                city.displayName.lowercased().contains(searchLower) ||
                city.code.lowercased().contains(searchLower)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Select Cities")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Choose cities to display in your timezone list:")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("24-hour time", isOn: $appState.use24HourTime)
                        .toggleStyle(.switch)
                }
            }
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search cities...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // City list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let displayedCities = Array(filteredCities.prefix(Constants.maxCitiesToDisplay))
                    ForEach(Array(displayedCities.enumerated()), id: \.element.code) { index, city in
                        CitySelectionRow(
                            city: city,
                            isSelected: selectedCityCodes.contains(city.code)
                        ) { isSelected in
                            if isSelected {
                                selectedCityCodes.insert(city.code)
                            } else {
                                selectedCityCodes.remove(city.code)
                            }
                        }
                        .padding(.horizontal, 4)

                        if index < displayedCities.count - 1 {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Action buttons
            HStack {
                Button(Constants.cancelButtonLabel) {
                    onClose()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("\(selectedCityCodes.count) cities selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if filteredCities.count > Constants.maxCitiesToDisplay {
                        Text("Showing \(Constants.maxCitiesToDisplay) of \(filteredCities.count) cities")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Button(Constants.saveButtonLabel) {
                    let selectedCities = appState.allAvailableTimezones.filter { 
                        selectedCityCodes.contains($0.code) 
                    }
                    appState.updateSelectedCities(selectedCities)
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCityCodes.isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(20)
        .onAppear {
            selectedCityCodes = Set(appState.selectedCities.map { $0.code })
        }
    }
    
    
}

struct CitySelectionRow: View {
    let city: City
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: { onToggle(!isSelected) }) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            
            // City info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(city.emoji) \(city.code)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    
                    Text(city.displayName)
                        .font(.body)
                    
                    Spacer()
                    
                    Text(getCurrentTimeString())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Text(city.timeZoneIdentifier)
                    .font(.caption)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle(!isSelected)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
    }
    
    private func getCurrentTimeString() -> String {
        return DateFormatterManager.formatShortTime(for: city)
    }
}

#Preview {
    CitySelectionView(onClose: {})
        .environmentObject(WeathervaneState())
        .frame(width: 500, height: 600)
}