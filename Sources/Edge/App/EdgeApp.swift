// Sources/Edge/App/EdgeApp.swift
import AppKit
import Foundation

@MainActor
public final class EdgeAppDelegate: NSObject, NSApplicationDelegate {
    public static private(set) var shared: EdgeAppDelegate?

    private var coordinator: EdgeAppCoordinator?

    public override init() {
        super.init()
        Self.shared = self
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize coordinator and start application services
        let appCoordinator = EdgeAppCoordinator.shared
        self.coordinator = appCoordinator
        appCoordinator.start()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
        coordinator = nil
        StatusBarController.shared.tearDown()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Edge is a menu bar utility — closing settings/onboarding windows must NOT quit the app!
        return false
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Re-opening Edge (e.g. from Finder, Spotlight, or Dock) displays the Settings window,
        // which is crucial if the menu bar icon is hidden!
        SettingsWindowController.shared.show()
        return true
    }
}
