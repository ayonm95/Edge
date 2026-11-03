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
}
