// Tests/EdgeTests/Unit/StatusBarControllerTests.swift
import Testing
import AppKit
@testable import Edge

@Suite("StatusBarController Unit Tests")
@MainActor
struct StatusBarControllerTests {

    @Test("Status icon symbols are valid system symbols")
    func iconStateSymbolsAreValidSystemSymbols() {
        let states: [Edge.StatusIconState] = [.idle, .tracking, .warning, .paused]
        for state in states {
            let symbolImage = NSImage(systemSymbolName: state.systemSymbolName, accessibilityDescription: state.accessibilityDescription)
            #expect(symbolImage != nil, "Symbol '\(state.systemSymbolName)' must be available in system SF Symbols")
        }
    }

    @Test("Status update transitions update state correctly")
    func statusUpdateTransitions() {
        let controller = StatusBarController()

        // 1. Initial active state
        controller.updateStatus(isEnabled: true, isAccessibilityGranted: true)
        #expect(controller.currentState == .idle)
        #expect(controller.isEnabled)
        #expect(controller.isAccessibilityGranted)

        // 2. Tracking active
        controller.setTrackingState(true)
        #expect(controller.currentState == .tracking)
        #expect(controller.isTracking)

        controller.setTrackingState(false)
        #expect(controller.currentState == .idle)

        // 3. Paused state
        controller.updateStatus(isEnabled: false, isAccessibilityGranted: true)
        #expect(controller.currentState == .paused)

        // 4. Missing permission state overrides enabled/paused
        controller.updateStatus(isEnabled: true, isAccessibilityGranted: false)
        #expect(controller.currentState == .warning)
    }

    @Test("Action callbacks respond to menu selectors")
    func actionCallbacks() {
        let controller = StatusBarController()
        var toggledState: Bool?
        controller.onToggleEnable = { state in
            toggledState = state
        }

        // Test toggle action selector
        let toggleSelector = #selector(StatusBarController.handleToggleEnable)
        if controller.responds(to: toggleSelector) {
            controller.perform(toggleSelector)
            #expect(toggledState != nil)
        }
    }
}
