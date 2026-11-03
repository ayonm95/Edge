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
            HStack(spacing: 8) {
                if permissionManager.isTrusted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Permission Granted! Edge is now active.")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                } else {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for permission in System Settings...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(permissionManager.isTrusted ? Color.green.opacity(0.12) : Color.secondary.opacity(0.1))
            )

            // Buttons
            HStack(spacing: 12) {
                Button(action: {
                    permissionManager.openSystemSettingsDeepLink()
                }) {
                    Label("Open System Settings", systemImage: "gearshape")
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.borderedProminent)

                if permissionManager.isTrusted {
                    Button(action: {
                        onDismiss?()
                    }) {
                        Text("Get Started")
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Dismiss for Now") {
                        onDismiss?()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(28)
        .frame(width: 480)
        .onAppear {
            permissionManager.startPolling(interval: 0.8)
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
