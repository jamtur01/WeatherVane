import SwiftUI

struct CombinedPopoverView: View {
    @ObservedObject var appState: WeathervaneState
    weak var statusBarController: CombinedStatusBarController?

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                content
                footer
            }
        }
        .frame(width: Constants.popoverWidth)
        .frame(minHeight: Constants.popoverHeightMin, maxHeight: Constants.popoverHeightMax)
    }

    @ViewBuilder
    private var content: some View {
        if appState.selectedCities.isEmpty {
            emptyState
        } else {
            cityList
        }
    }

    private var cityList: some View {
        ScrollView {
            VStack(spacing: Constants.rowSpacing) {
                ForEach(appState.selectedCities, id: \.code) { city in
                    TimezoneRow(
                        city: city,
                        weather: appState.getWeather(for: city),
                        isLoading: appState.isLoading(for: city),
                        error: appState.getError(for: city),
                        effectiveNow: appState.effectiveNow,
                        use24Hour: appState.use24HourTime,
                        isFrozen: appState.isVirtualTime,
                        onRetry: { appState.fetchWeather(for: city) },
                        onDrag: { newDate in
                            appState.setVirtualNow(newDate)
                        },
                        onReset: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                appState.resetTime()
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No cities yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Add some to start tracking time and weather.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                statusBarController?.openSettingsWindow()
            } label: {
                Label("Add City", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Divider().opacity(0.5)

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    appState.resetTime()
                }
            } label: {
                Text("Reset")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(!appState.isVirtualTime)
            .padding(.horizontal, 12)

            HStack {
                footerButton(systemImage: "plus", label: "Add") {
                    statusBarController?.openSettingsWindow()
                }
                Spacer()
                footerButton(systemImage: "gearshape", label: "Settings") {
                    statusBarController?.openSettingsWindow()
                }
                Spacer()
                footerButton(systemImage: "power", label: "Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 10)
        }
    }

    private func footerButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
}
