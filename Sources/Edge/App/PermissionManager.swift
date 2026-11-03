// Sources/Edge/App/PermissionManager.swift
import Foundation
import AppKit
import ApplicationServices

/// Coordinates macOS Accessibility permission status verification, prompt dialogs,
/// deep-link navigation to System Settings, and active polling.
@MainActor
public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    public static let accessibilitySettingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    @Published public private(set) var isTrusted: Bool = false
    private var pollTimer: Timer?
    public var onTrustChanged: ((Bool) -> Void)?

    public init() {
        self.isTrusted = Self.checkIsTrusted()
    }

    /// Evaluates whether the current application process has been granted macOS Accessibility access.
    public static func checkIsTrusted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Triggers the system accessibility permission prompt if not currently trusted.
    @discardableResult
    public func promptAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        let previous = self.isTrusted
        self.isTrusted = trusted
        if trusted != previous {
            onTrustChanged?(trusted)
        }
        return trusted
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Accessibility.
    public func openSystemSettingsDeepLink() {
        if let url = URL(string: Self.accessibilitySettingsURL) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Starts polling accessibility status at regular intervals (default: 1.0s)
    /// to dynamically detect when the user grants permission in System Settings.
    public func startPolling(interval: TimeInterval = 1.0) {
        stopPolling()
        refreshTrust()
        // Battery optimization: If already trusted, do not run background timer
        guard !isTrusted else { return }

        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshTrust()
            }
        }
    }

    /// Halts active polling.
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Indicates whether background polling is actively running.
    public var isPolling: Bool {
        return pollTimer != nil
    }

    /// Refreshes the cached trust status and notifies observers if it changed.
    public func refreshTrust() {
        let currentlyTrusted = Self.checkIsTrusted()
        if currentlyTrusted != isTrusted {
            isTrusted = currentlyTrusted
            onTrustChanged?(currentlyTrusted)
        }
        // As soon as permission is granted, stop polling immediately to conserve CPU cycles & battery
        if currentlyTrusted {
            stopPolling()
        }
    }

    deinit {
        pollTimer?.invalidate()
    }
}
