// Sources/Edge/App/StatusBarController.swift
import AppKit
import Foundation

/// Represents the visual states of the Edge status bar icon.
public enum StatusIconState: String, Sendable, Equatable {
    case idle
    case tracking
    case warning
    case paused

    public var systemSymbolName: String {
        switch self {
        case .idle:
            return "slider.horizontal.3"
        case .tracking:
            return "slider.horizontal.below.rectangle"
        case .warning:
            return "exclamationmark.triangle"
        case .paused:
            return "pause.circle"
        }
    }

    public var accessibilityDescription: String {
        switch self {
        case .idle:
            return "Edge Active"
        case .tracking:
            return "Edge Gesture Active"
        case .warning:
            return "Edge Permission Required"
        case .paused:
            return "Edge Controls Paused"
        }
    }
}

/// Coordinates the NSStatusItem, template icons, and menu bar interaction.
@MainActor
public final class StatusBarController: NSObject, NSMenuDelegate {
    public static let shared = StatusBarController()

    // MARK: - Properties
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!

    // Menu Items
    private var statusHeaderItem: NSMenuItem!
    private var toggleItem: NSMenuItem!
    private var permissionWarningItem: NSMenuItem!
    private var settingsItem: NSMenuItem!
    private var checkPermissionsItem: NSMenuItem!
    private var aboutItem: NSMenuItem!
    private var quitItem: NSMenuItem!

    // State
    public private(set) var currentState: StatusIconState = .idle
    public private(set) var isEnabled: Bool = true
    public private(set) var isAccessibilityGranted: Bool = true
    public private(set) var isTracking: Bool = false

    // MARK: - Action Callbacks (For Coordinator Integration)
    public var onToggleEnable: ((Bool) -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var onOpenOnboarding: (() -> Void)?
    public var onCheckPermissions: (() -> Void)?
    public var onQuit: (() -> Void)?

    // MARK: - Initialization
    public override init() {
        super.init()
        setupStatusItem()
        setupMenu()
        applyIconState(.idle)
    }

    // MARK: - Setup
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.toolTip = "Edge — Trackpad Edge Controller"
        button.imagePosition = .imageOnly
        statusItem.isVisible = Preferences.shared.showMenuBarIcon
    }

    private func setupMenu() {
        menu = NSMenu(title: "Edge Menu")
        menu.autoenablesItems = false
        menu.delegate = self

        // 1. Header / Status Display (disabled non-interactive text)
        statusHeaderItem = NSMenuItem(title: "Edge — Active", action: nil, keyEquivalent: "")
        statusHeaderItem.isEnabled = false
        menu.addItem(statusHeaderItem)

        // 2. Accessibility Warning Item (hidden when granted)
        permissionWarningItem = NSMenuItem(
            title: "⚠️ Accessibility Permission Needed...",
            action: #selector(handleOpenOnboarding),
            keyEquivalent: ""
        )
        permissionWarningItem.target = self
        permissionWarningItem.isHidden = true
        menu.addItem(permissionWarningItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Quick Toggle Enable / Pause
        toggleItem = NSMenuItem(
            title: "Enable Edge Controls",
            action: #selector(handleToggleEnable),
            keyEquivalent: "e"
        )
        toggleItem.target = self
        toggleItem.state = .on
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Preferences / Settings
        settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(handleOpenSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // 5. Check Permissions
        checkPermissionsItem = NSMenuItem(
            title: "Check Permissions...",
            action: #selector(handleCheckPermissions),
            keyEquivalent: ""
        )
        checkPermissionsItem.target = self
        menu.addItem(checkPermissionsItem)

        menu.addItem(NSMenuItem.separator())

        // 6. About Edge
        aboutItem = NSMenuItem(
            title: "About Edge",
            action: #selector(handleAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // 7. Quit Edge
        quitItem = NSMenuItem(
            title: "Quit Edge",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - State Management API

    /// Updates the overall status state and refreshes icon and menu items.
    public func updateStatus(isEnabled: Bool, isAccessibilityGranted: Bool) {
        self.isEnabled = isEnabled
        self.isAccessibilityGranted = isAccessibilityGranted

        let calculatedState: StatusIconState
        if !isAccessibilityGranted {
            calculatedState = .warning
        } else if !isEnabled {
            calculatedState = .paused
        } else if isTracking {
            calculatedState = .tracking
        } else {
            calculatedState = .idle
        }

        applyIconState(calculatedState)
        refreshMenuItems()
    }

    /// Controls visibility of the status bar item in the macOS menu bar.
    public func setVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    /// Whether the status bar item is currently visible.
    public var isVisible: Bool {
        return statusItem.isVisible
    }

    /// Sets whether an edge slide gesture is actively engaged.
    public func setTrackingState(_ isTracking: Bool) {
        self.isTracking = isTracking
        if isAccessibilityGranted && isEnabled {
            applyIconState(isTracking ? .tracking : .idle)
        }
    }

    private func applyIconState(_ state: StatusIconState) {
        self.currentState = state
        guard let button = statusItem.button else { return }

        let symbolImage = NSImage(
            systemSymbolName: state.systemSymbolName,
            accessibilityDescription: state.accessibilityDescription
        ) ?? NSImage(
            systemSymbolName: "slider.horizontal.3",
            accessibilityDescription: state.accessibilityDescription
        ) ?? NSImage()

        symbolImage.isTemplate = true
        button.image = symbolImage
    }

    private func refreshMenuItems() {
        toggleItem.state = isEnabled ? .on : .off
        permissionWarningItem.isHidden = isAccessibilityGranted

        if !isAccessibilityGranted {
            statusHeaderItem.title = "Edge — Permission Needed"
        } else if !isEnabled {
            statusHeaderItem.title = "Edge — Paused"
        } else if isTracking {
            statusHeaderItem.title = "Edge — Tracking Gesture"
        } else {
            statusHeaderItem.title = "Edge — Active"
        }
    }

    // MARK: - Teardown
    public func tearDown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
    }

    // MARK: - Action Handlers

    @objc public func handleToggleEnable() {
        isEnabled.toggle()
        updateStatus(isEnabled: isEnabled, isAccessibilityGranted: isAccessibilityGranted)
        onToggleEnable?(isEnabled)
    }

    @objc private func handleOpenSettings() {
        if let onOpenSettings = onOpenSettings {
            onOpenSettings()
        } else {
            SettingsWindowController.shared.show()
        }
    }

    @objc private func handleOpenOnboarding() {
        if let onOpenOnboarding = onOpenOnboarding {
            onOpenOnboarding()
        } else {
            // Default deep link to macOS Accessibility Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func handleCheckPermissions() {
        if let onCheckPermissions = onCheckPermissions {
            onCheckPermissions()
            return
        }

        let trusted = AXIsProcessTrusted()
        updateStatus(isEnabled: isEnabled, isAccessibilityGranted: trusted)

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        if trusted {
            alert.messageText = "Accessibility Privileges Active"
            alert.informativeText = "Edge is authorized to track trackpad gestures and adjust system volume and brightness."
            alert.alertStyle = .informational
        } else {
            alert.messageText = "Accessibility Privileges Missing"
            alert.informativeText = "Edge requires accessibility permission to detect edge touch coordinates. Please enable Edge in System Settings."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
        }

        let response = alert.runModal()
        if !trusted && response == .alertFirstButtonReturn {
            handleOpenOnboarding()
        }
    }

    @objc private func handleAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func handleQuit() {
        if let onQuit = onQuit {
            onQuit()
        } else {
            NSApp.terminate(nil)
        }
    }
}
