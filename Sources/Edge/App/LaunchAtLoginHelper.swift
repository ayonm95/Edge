// Sources/Edge/App/LaunchAtLoginHelper.swift
import Foundation
import ServiceManagement
import AppKit

/// Helper managing auto-start at login using modern macOS 13+ SMAppService.
public enum LaunchAtLoginHelper {
    
    public enum Status: Equatable, Sendable {
        case enabled
        case disabled
        case requiresApproval
        case bundleRequired
        case error(String)
    }
    
    /// Queries the current SMAppService status
    public static var currentStatus: Status {
        let serviceStatus = SMAppService.mainApp.status
        switch serviceStatus {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .bundleRequired
        @unknown default:
            return .disabled
        }
    }
    
    /// Checks if launch at login is currently active
    public static var isEnabled: Bool {
        return SMAppService.mainApp.status == .enabled
    }
    
    /// Registers or unregisters the app with SMAppService
    public static func setEnabled(_ enable: Bool) throws {
        if enable {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    }
    
    /// Opens macOS System Settings directly to Login Items
    public static func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Opens macOS System Settings directly to Accessibility Privacy
    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
