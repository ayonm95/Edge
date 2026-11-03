// Sources/Edge/Model/Preferences.swift
import Foundation
import SwiftUI
import ServiceManagement
import os

/// Main-thread observable settings store providing SwiftUI two-way bindings
/// and synchronizing persistent user defaults with the atomic gesture snapshot.
@MainActor
public final class Preferences: ObservableObject {
    /// Shared singleton instance used throughout the app lifecycle.
    public static let shared = Preferences()

    // MARK: - Storage Keys

    public enum Keys {
        public static let isEnabled = "edge_isEnabled"
        public static let swapSides = "edge_swapSides"
        public static let edgeWidth = "edge_edgeWidth"
        public static let sensitivity = "edge_sensitivity"
        public static let activeArea = "edge_activeArea"
        public static let reverseMediaSwipe = "edge_reverseMediaSwipe"
        public static let preciseSliding = "edge_preciseSliding"
        public static let enableMagicMouse = "edge_enableMagicMouse"
        public static let showOSD = "edge_showOSD"
        public static let enableHaptics = "edge_enableHaptics"
        public static let showMenuBarIcon = "edge_showMenuBarIcon"
        public static let requireTwoFingerSlide = "edge_requireTwoFingerSlide"
    }

    private let defaults: UserDefaults
    public let holder: AtomicPreferencesHolder

    /// Direct accessor for the underlying thread-safe atomic snapshot holder.
    public nonisolated var atomicHolder: AtomicPreferencesHolder { holder }

    // MARK: - Published Properties

    @Published public var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
            syncSnapshot()
        }
    }

    @Published public var swapSides: Bool {
        didSet {
            defaults.set(swapSides, forKey: Keys.swapSides)
            syncSnapshot()
        }
    }

    @Published public var edgeWidth: Double {
        didSet {
            let clamped = min(max(edgeWidth, PreferencesSnapshot.edgeWidthRange.lowerBound), PreferencesSnapshot.edgeWidthRange.upperBound)
            if edgeWidth != clamped {
                edgeWidth = clamped
                return
            }
            defaults.set(edgeWidth, forKey: Keys.edgeWidth)
            syncSnapshot()
        }
    }

    @Published public var sensitivity: Double {
        didSet {
            let clamped = min(max(sensitivity, PreferencesSnapshot.sensitivityRange.lowerBound), PreferencesSnapshot.sensitivityRange.upperBound)
            if sensitivity != clamped {
                sensitivity = clamped
                return
            }
            defaults.set(sensitivity, forKey: Keys.sensitivity)
            syncSnapshot()
        }
    }

    @Published public var activeArea: ActiveAreaZone {
        didSet {
            defaults.set(activeArea.rawValue, forKey: Keys.activeArea)
            syncSnapshot()
        }
    }

    @Published public var reverseMediaSwipe: Bool {
        didSet {
            defaults.set(reverseMediaSwipe, forKey: Keys.reverseMediaSwipe)
            syncSnapshot()
        }
    }

    @Published public var preciseSliding: Bool {
        didSet {
            defaults.set(preciseSliding, forKey: Keys.preciseSliding)
            syncSnapshot()
        }
    }

    @Published public var enableMagicMouse: Bool {
        didSet {
            defaults.set(enableMagicMouse, forKey: Keys.enableMagicMouse)
            syncSnapshot()
        }
    }

    @Published public var showOSD: Bool {
        didSet {
            defaults.set(showOSD, forKey: Keys.showOSD)
            syncSnapshot()
        }
    }

    @Published public var enableHaptics: Bool {
        didSet {
            defaults.set(enableHaptics, forKey: Keys.enableHaptics)
            syncSnapshot()
        }
    }

    @Published public var showMenuBarIcon: Bool {
        didSet {
            defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon)
            syncSnapshot()
            StatusBarController.shared.setVisible(showMenuBarIcon)
        }
    }

    @Published public var requireTwoFingerSlide: Bool {
        didSet {
            defaults.set(requireTwoFingerSlide, forKey: Keys.requireTwoFingerSlide)
            syncSnapshot()
        }
    }

    // MARK: - Open at Login (SMAppService Integration)

    /// Reflects whether Edge is currently registered to launch automatically at login.
    @Published public private(set) var launchAtLoginStatus: SMAppService.Status = .notRegistered

    public var isLaunchAtLoginEnabled: Bool {
        get {
            return launchAtLoginStatus == .enabled
        }
        set {
            setLaunchAtLogin(newValue)
        }
    }

    // MARK: - Initialization

    /// Initializes preferences with customizable defaults suite and snapshot holder for testing.
    public init(
        defaults: UserDefaults = .standard,
        holder: AtomicPreferencesHolder = .shared
    ) {
        self.defaults = defaults
        self.holder = holder

        // 1. Register canonical fallback defaults
        defaults.register(defaults: [
            Keys.isEnabled: true,
            Keys.swapSides: false,
            Keys.edgeWidth: PreferencesSnapshot.defaultEdgeWidth,
            Keys.sensitivity: PreferencesSnapshot.defaultSensitivity,
            Keys.activeArea: ActiveAreaZone.entire.rawValue,
            Keys.reverseMediaSwipe: false,
            Keys.preciseSliding: false,
            Keys.enableMagicMouse: false,
            Keys.showOSD: true,
            Keys.enableHaptics: true,
            Keys.showMenuBarIcon: true,
            Keys.requireTwoFingerSlide: true
        ])

        // 2. Load stored values (or registered defaults)
        self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
        self.swapSides = defaults.bool(forKey: Keys.swapSides)

        let rawWidth = defaults.double(forKey: Keys.edgeWidth)
        self.edgeWidth = min(max(rawWidth, PreferencesSnapshot.edgeWidthRange.lowerBound), PreferencesSnapshot.edgeWidthRange.upperBound)

        let rawSens = defaults.double(forKey: Keys.sensitivity)
        self.sensitivity = min(max(rawSens, PreferencesSnapshot.sensitivityRange.lowerBound), PreferencesSnapshot.sensitivityRange.upperBound)

        let rawArea = defaults.string(forKey: Keys.activeArea) ?? ""
        self.activeArea = ActiveAreaZone(rawValue: rawArea) ?? .entire

        self.reverseMediaSwipe = defaults.bool(forKey: Keys.reverseMediaSwipe)
        self.preciseSliding = defaults.bool(forKey: Keys.preciseSliding)
        self.enableMagicMouse = defaults.bool(forKey: Keys.enableMagicMouse)
        self.showOSD = defaults.bool(forKey: Keys.showOSD)
        self.enableHaptics = defaults.bool(forKey: Keys.enableHaptics)
        self.showMenuBarIcon = defaults.object(forKey: Keys.showMenuBarIcon) as? Bool ?? true
        self.requireTwoFingerSlide = defaults.object(forKey: Keys.requireTwoFingerSlide) as? Bool ?? true

        // 3. Update login item status
        refreshLaunchAtLoginStatus()

        // 4. Initial atomic snapshot sync
        syncSnapshot()
    }

    // MARK: - Snapshot Synchronization

    /// Pushes the current settings values to the atomic holder for 120Hz gesture engine access.
    public func syncSnapshot() {
        let snapshot = PreferencesSnapshot(
            isEnabled: isEnabled,
            swapSides: swapSides,
            edgeWidth: edgeWidth,
            sensitivity: sensitivity,
            activeArea: activeArea,
            reverseMediaSwipe: reverseMediaSwipe,
            preciseSliding: preciseSliding,
            enableMagicMouse: enableMagicMouse,
            showOSD: showOSD,
            enableHaptics: enableHaptics,
            showMenuBarIcon: showMenuBarIcon,
            requireTwoFingerSlide: requireTwoFingerSlide
        )
        holder.set(snapshot)
    }

    /// Returns the current atomic snapshot.
    public var currentSnapshot: PreferencesSnapshot {
        return holder.get()
    }

    /// Resets all preference values back to their canonical defaults.
    public func resetToDefaults() {
        let def = PreferencesSnapshot.default
        self.isEnabled = def.isEnabled
        self.swapSides = def.swapSides
        self.edgeWidth = def.edgeWidth
        self.sensitivity = def.sensitivity
        self.activeArea = def.activeArea
        self.reverseMediaSwipe = def.reverseMediaSwipe
        self.preciseSliding = def.preciseSliding
        self.enableMagicMouse = def.enableMagicMouse
        self.showOSD = def.showOSD
        self.enableHaptics = def.enableHaptics
        self.showMenuBarIcon = def.showMenuBarIcon
        self.requireTwoFingerSlide = def.requireTwoFingerSlide
        syncSnapshot()
        StatusBarController.shared.setVisible(showMenuBarIcon)
    }

    // MARK: - Login Item Helper Methods

    /// Refreshes current SMAppService status.
    public func refreshLaunchAtLoginStatus() {
        self.launchAtLoginStatus = SMAppService.mainApp.status
    }

    /// Registers or unregisters the app with SMAppService.
    @discardableResult
    public func setLaunchAtLogin(_ enable: Bool) -> Bool {
        do {
            if enable {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            refreshLaunchAtLoginStatus()
            return true
        } catch {
            // When executing unbundled via `swift run`, SMAppService throws NotFound.
            // This is expected during development; we update the status accordingly.
            refreshLaunchAtLoginStatus()
            return false
        }
    }
}
