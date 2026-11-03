// Sources/Edge/UI/Settings/SettingsView.swift
import SwiftUI
import ServiceManagement

/// View model managing transient settings UI state.
@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var launchAtLoginStatus: LaunchAtLoginHelper.Status = LaunchAtLoginHelper.currentStatus
    @Published public var launchAtLoginToggle: Bool = LaunchAtLoginHelper.isEnabled
    @Published public var errorMessage: String? = nil

    public init() {}

    public func refresh() {
        launchAtLoginStatus = LaunchAtLoginHelper.currentStatus
        launchAtLoginToggle = LaunchAtLoginHelper.isEnabled
    }

    public func toggleLaunchAtLogin(_ newValue: Bool) {
        do {
            try LaunchAtLoginHelper.setEnabled(newValue)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }
}

/// Primary Settings View for the Edge macOS menu bar application.
/// Organized into Gestures & Tuning, General, and Media & Devices.
public struct SettingsView: View {
    @ObservedObject private var preferences = Preferences.shared
    @StateObject private var viewModel = SettingsViewModel()

    public init() {}

    public var body: some View {
        TabView {
            GestureTuningTab(preferences: preferences)
                .tabItem {
                    Label("Gestures & Tuning", systemImage: "hand.draw")
                }
                .tag(0)

            GeneralTab(
                preferences: preferences,
                viewModel: viewModel
            )
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .tag(1)

            MediaAndDeviceTab(preferences: preferences)
                .tabItem {
                    Label("Media & Devices", systemImage: "playpause.fill")
                }
                .tag(2)
        }
        .frame(width: 580, height: 610)
        .padding(16)
        .onAppear {
            viewModel.refresh()
        }
    }
}

// MARK: - Gesture Tuning Tab
struct GestureTuningTab: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Interactive Trackpad Live Visualizer
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Live Trackpad Preview")
                            .font(.headline)
                        Spacer()
                        Text("Touch trackpad or drag below to test")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    TrackpadPreviewView(
                        edgeWidth: preferences.edgeWidth,
                        activeArea: preferences.activeArea,
                        swapSides: preferences.swapSides,
                        reverseMediaSwipe: preferences.reverseMediaSwipe
                    )
                    .frame(height: 180)
                }

                // How to Swipe Guide
                VStack(alignment: .leading, spacing: 10) {
                    Label("How to Swipe on Your Trackpad", systemImage: "hand.tap.fill")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        GestureGuideRow(
                            icon: preferences.swapSides ? "sun.max.fill" : "speaker.wave.2.fill",
                            color: preferences.swapSides ? .orange : .blue,
                            title: preferences.swapSides ? "Right Edge: Brightness ☀️" : "Right Edge: Volume 🔊",
                            action: preferences.requireTwoFingerSlide
                                ? "Swipe 2 fingers up or down along the right edge of the trackpad glass."
                                : "Slide 1 or 2 fingers up or down along the right edge of the trackpad glass."
                        )

                        GestureGuideRow(
                            icon: preferences.swapSides ? "speaker.wave.2.fill" : "sun.max.fill",
                            color: preferences.swapSides ? .blue : .orange,
                            title: preferences.swapSides ? "Left Edge: Volume 🔊" : "Left Edge: Brightness ☀️",
                            action: preferences.requireTwoFingerSlide
                                ? "Swipe 2 fingers up or down along the left edge of the trackpad glass."
                                : "Slide 1 or 2 fingers up or down along the left edge of the trackpad glass."
                        )

                        GestureGuideRow(
                            icon: "speaker.slash.fill",
                            color: .red,
                            title: "Top-Right Corner: Quick Mute 🔇",
                            action: "Double-tap the top-right corner with 1 finger to instantly toggle mute/unmute."
                        )

                        GestureGuideRow(
                            icon: "playpause.fill",
                            color: .purple,
                            title: "Bottom Strip: Media Navigation ⏯",
                            action: "Swipe along bottom to skip tracks; double-tap with 1 finger to Play/Pause."
                        )
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(preferences.requireTwoFingerSlide
                            ? "Sliders require 2 fingers along the edge. Quick Mute is 1-finger double tap in the top-right corner."
                            : "Sliders work with edge swipes. Quick Mute is a 1-finger double tap in the top-right corner.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Slider Fingers Mode Toggle
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Require Two-Finger Swipe for Sliders", isOn: $preferences.requireTwoFingerSlide)
                        .font(.headline)

                    Text("Requires a 2-finger swipe along the left/right edge to adjust volume and brightness. Single-finger touch is reserved for standard cursor movement and 1-finger Quick Mute.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Edge Width Slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Edge Detection Margin:")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(preferences.edgeWidth * 100))% surface width")
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: $preferences.edgeWidth,
                        in: 0.03...0.20,
                        step: 0.01
                    )

                    Text("Wider margins make edges easier to reach; narrower margins reduce accidental triggers while typing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Sensitivity Multiplier Slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Gesture Sensitivity:")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.1fx Multiplier", preferences.sensitivity))
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: $preferences.sensitivity,
                        in: 0.5...2.5,
                        step: 0.1
                    )

                    Text("Controls volume/brightness speed. Higher values require less vertical finger travel.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Active Area Picker
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Active Edge Height (Palm Rejection):")
                            .font(.headline)
                        Spacer()
                        Text(preferences.activeArea.percentageString)
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    Picker("Active Area", selection: $preferences.activeArea) {
                        ForEach(ActiveAreaZone.allCases) { zone in
                            Text(zone.title).tag(zone)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Restricts edge triggers to the lower portion of the trackpad to prevent resting palm triggers.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - General Tab
struct GeneralTab: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // App Identity & Icon
            HStack(spacing: 14) {
                if let iconImage = NSImage(named: "AppIcon") ?? NSImage(contentsOfFile: Bundle.main.path(forResource: "AppIcon_1024", ofType: "png") ?? "") {
                    Image(nsImage: iconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                } else {
                    Image(systemName: "slider.horizontal.below.rectangle")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Edge")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("v1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                    Text("Physical trackpad edge sliders for volume & brightness")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 2)

            Divider()

            // Control Placement / Side Swapping
            VStack(alignment: .leading, spacing: 8) {
                Text("Control Placement")
                    .font(.headline)

                Picker("", selection: $preferences.swapSides) {
                    HStack {
                        Label("Normal Placement", systemImage: "sun.max.fill")
                        Text("— Left: Brightness | Right: Volume")
                            .foregroundColor(.secondary)
                    }
                    .tag(false)

                    HStack {
                        Label("Swapped Placement", systemImage: "speaker.wave.2.fill")
                        Text("— Left: Volume | Right: Brightness")
                            .foregroundColor(.secondary)
                    }
                    .tag(true)
                }
                .pickerStyle(.radioGroup)
            }

            Divider()

            // Launch at Login Section
            VStack(alignment: .leading, spacing: 8) {
                Text("System Startup")
                    .font(.headline)

                HStack {
                    Toggle(
                        "Open at Login",
                        isOn: Binding(
                            get: { viewModel.launchAtLoginToggle },
                            set: { newValue in viewModel.toggleLaunchAtLogin(newValue) }
                        )
                    )

                    Spacer()

                    // Status Badge
                    statusBadgeView
                }

                if viewModel.launchAtLoginStatus == .requiresApproval {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Disabled in System Settings. Please enable in Login Items.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Open Settings") {
                            LaunchAtLoginHelper.openLoginItemsSettings()
                        }
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color.yellow.opacity(0.12))
                    .cornerRadius(6)
                } else if viewModel.launchAtLoginStatus == .bundleRequired {
                    Text("Note: Auto-start requires installing Edge into /Applications as an app bundle.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Precision Mode
            VStack(alignment: .leading, spacing: 8) {
                Text("Precision Tuning")
                    .font(.headline)

                Toggle("Enable Precise Sliding Mode", isOn: $preferences.preciseSliding)

                Text("Uses quarter-step (1/64 increments) for fine-grained volume and brightness control.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Menu Bar Visibility
            VStack(alignment: .leading, spacing: 8) {
                Text("Menu Bar")
                    .font(.headline)

                Toggle("Show Menu Bar Icon", isOn: $preferences.showMenuBarIcon)

                Text("When disabled, the menu bar icon is hidden. To access Settings again, reopen Edge from Applications or Spotlight.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusBadgeView: some View {
        switch viewModel.launchAtLoginStatus {
        case .enabled:
            Label("Active", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .disabled:
            Label("Disabled", systemImage: "circle")
                .foregroundColor(.secondary)
                .font(.caption)
        case .requiresApproval:
            Label("Approval Needed", systemImage: "exclamationmark.circle.fill")
                .foregroundColor(.yellow)
                .font(.caption)
        case .bundleRequired:
            Label("Bundle Required", systemImage: "info.circle")
                .foregroundColor(.secondary)
                .font(.caption)
        case .error:
            Label("Error", systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
        }
    }
}

// MARK: - Media & Device Tab
struct MediaAndDeviceTab: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Media Strip
            VStack(alignment: .leading, spacing: 8) {
                Text("Bottom Edge Media Strip")
                    .font(.headline)

                Toggle("Reverse Media Swipe Direction", isOn: $preferences.reverseMediaSwipe)

                Text(preferences.reverseMediaSwipe
                     ? "Current: Swipe Left = Next Track ⏭ | Swipe Right = Previous Track ⏮"
                     : "Current: Swipe Right = Next Track ⏭ | Swipe Left = Previous Track ⏮")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Device Support
            VStack(alignment: .leading, spacing: 8) {
                Text("Hardware Peripherals")
                    .font(.headline)

                Toggle("Enable Magic Mouse Surface", isOn: $preferences.enableMagicMouse)

                Text("Allows edge swipes along the multi-touch shell of an external Apple Magic Mouse.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Feedback & Overlays
            VStack(alignment: .leading, spacing: 10) {
                Text("Feedback & HUD")
                    .font(.headline)

                Toggle("Haptic Feedback on Step Change", isOn: $preferences.enableHaptics)
                Text("Triggers discrete Taptic Engine pulses on step adjustments.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Show On-Screen Display (OSD HUD)", isOn: $preferences.showOSD)
                Text("Presents floating liquid-glass bezel indicator when hardware values change.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

// MARK: - Gesture Guide Helper Row

struct GestureGuideRow: View {
    let icon: String
    let color: Color
    let title: String
    let action: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(action)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
