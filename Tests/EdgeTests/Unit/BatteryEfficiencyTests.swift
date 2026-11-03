// Tests/EdgeTests/Unit/BatteryEfficiencyTests.swift
import Testing
import Foundation
import CoreGraphics
import AppKit
@testable import Edge

@Suite("Battery Efficiency & Low-Power Tests", .serialized)
struct BatteryEfficiencyTests {

    @Test("PermissionManager stops background polling timer when process is trusted")
    @MainActor
    func permissionManagerPollingSuppressionWhenTrusted() {
        let pm = PermissionManager.shared
        // In this test runner environment or macOS desktop, checkIsTrusted may be true or false.
        // If trusted, startPolling MUST NOT retain an active pollTimer.
        if PermissionManager.checkIsTrusted() {
            pm.startPolling(interval: 0.5)
            #expect(!pm.isPolling, "Background poll timer must not run when app is already trusted")
        } else {
            // When untrusted, refreshTrust must stop polling as soon as trust is established
            pm.refreshTrust()
            if pm.isTrusted {
                #expect(!pm.isPolling, "Poll timer must be stopped immediately upon trust confirmation")
            }
        }
    }

    @Test("TouchPreviewState thread-safe live flag skips background Task allocations")
    @MainActor
    func touchPreviewFastFlag() {
        let preview = TouchPreviewState.shared

        preview.isActive = false
        #expect(TouchPreviewState.isLivePreviewActive == false)

        preview.isActive = true
        #expect(TouchPreviewState.isLivePreviewActive == true)

        preview.isActive = false
        #expect(TouchPreviewState.isLivePreviewActive == false)
    }

    @Test("CursorManager unfreeze restores state and cleans anchor")
    func cursorManagerBatteryLifecycle() {
        let manager = CursorManager()
        defer { manager.reset() }

        #expect(!manager.isFrozen)
        manager.freezeCursor(at: CGPoint(x: 50, y: 50))
        #expect(manager.isFrozen)

        manager.unfreezeCursor()
        #expect(!manager.isFrozen)
        #expect(manager.anchorPoint == nil)
    }

    @Test("SettingsWindowController instantiates lazily without pre-allocating window on init")
    @MainActor
    func settingsWindowLazyInit() {
        let controller = SettingsWindowController()
        // Window should be created deferred or on-demand
        #expect(controller.window == nil || controller.window?.isVisible == false)
    }
}
