// Sources/Edge/UI/Onboarding/OnboardingView.swift
import SwiftUI

/// Onboarding guidance view presented on first launch when Accessibility access is needed.
public struct OnboardingView: View {
    @ObservedObject private var permissionManager = PermissionManager.shared
    public var onDismiss: (() -> Void)?

    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 10) {
                if let iconImage = NSImage(named: "AppIcon") ?? NSImage(contentsOfFile: Bundle.main.path(forResource: "AppIcon_1024", ofType: "png") ?? "") {
                    Image(nsImage: iconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                } else {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.indigo.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)

                        Image(systemName: "slider.horizontal.below.rectangle")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                Text("Welcome to Edge")
                    .font(.system(size: 22, weight: .bold))

                Text("Turn the edges of your MacBook trackpad into physical sliders for volume, brightness, quick mute, and media playback.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // Permission Card
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "hand.raised.square.fill")
                        .font(.title2)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility Permission Required")
                            .font(.headline)
                        Text("macOS requires this to detect edge touch coordinates and keep your cursor locked while sliding.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Step by step
                VStack(alignment: .leading, spacing: 10) {
                    StepRow(number: "1", text: "Click the button below to open Privacy & Security.")
                    StepRow(number: "2", text: "Find Edge in the Accessibility list and switch it ON.")
                    StepRow(number: "3", text: "Edge will immediately detect the change and activate.")
                }

                Divider()

                // Gesture Guide Summary
                VStack(alignment: .leading, spacing: 6) {
                    Text("How Gestures Work (Single Finger):")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    HStack(spacing: 14) {
                        Label("Right: Volume", systemImage: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Label("Left: Brightness", systemImage: "sun.max.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Label("Corner: Mute", systemImage: "speaker.slash.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    Text("💡 Slide 1 finger right along the physical edge of the trackpad glass.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            // Dynamic Trust Status Indicator
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    if permissionManager.isTrusted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Permission Granted! Edge is fully active.")
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    } else {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                        Text("Sliders are active! Accessibility enables cursor lock.")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(permissionManager.isTrusted ? Color.green.opacity(0.12) : Color.blue.opacity(0.1))
                )

                if !permissionManager.isTrusted {
                    Text("Tip: In System Settings, toggle Edge OFF and ON to refresh macOS permission.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Action Buttons
            HStack(spacing: 10) {
                Button(action: {
                    permissionManager.openSystemSettingsDeepLink()
                }) {
                    Label("System Settings", systemImage: "gearshape")
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    permissionManager.promptAccessibility()
                }) {
                    Label("Check Now", systemImage: "arrow.clockwise")
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    onDismiss?()
                }) {
                    Text("Continue to Edge")
                        .fontWeight(.semibold)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .padding(28)
        .frame(width: 480)
        .onAppear {
            if !permissionManager.isTrusted {
                permissionManager.startPolling(interval: 0.8)
            }
        }
    }
}

private struct StepRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 20, height: 20)
                Text(number)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
            }
            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
}
