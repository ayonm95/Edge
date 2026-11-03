// Tests/EdgeTests/Unit/HardwareTests.swift
import Testing
import Foundation
import AppKit
import struct SwiftUI.AnyView
@testable import Edge

final class SendableBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

@Suite("Hardware & HUD Unit Tests", .serialized)
@MainActor
struct HardwareTests {

    // MARK: - 1. AudioController Unit Tests

    @Test("AudioController conforms to AudioControlling")
    func audioControllerProtocolConformance() {
        let controller: any Edge.AudioControlling = Edge.AudioController()
        #expect(controller.getVolume() >= 0.0 && controller.getVolume() <= 1.0)
    }

    @Test("AudioController setVolume clamps within [0.0, 1.0]")
    func audioControllerVolumeClamping() {
        let controller = Edge.AudioController()
        let origVolume = controller.getVolume()
        let origMuted = controller.isMuted()
        defer {
            controller.setVolume(origVolume)
            if controller.isMuted() != origMuted {
                _ = controller.toggleMute()
            }
        }

        controller.setVolume(1.5)
        #expect(controller.getVolume() == 1.0)

        controller.setVolume(-0.5)
        #expect(controller.getVolume() == 0.0)

        controller.setVolume(0.42)
        #expect(abs(controller.getVolume() - 0.42) < 0.001)
    }

    @Test("AudioController setting non-zero volume un-mutes automatically")
    func audioControllerUnmuteOnNonZeroVolume() {
        let controller = Edge.AudioController()
        let origVolume = controller.getVolume()
        let origMuted = controller.isMuted()
        defer {
            controller.setVolume(origVolume)
            if controller.isMuted() != origMuted {
                _ = controller.toggleMute()
            }
        }

        // Mute first
        if !controller.isMuted() {
            _ = controller.toggleMute()
        }
        #expect(controller.isMuted())

        // Setting positive volume un-mutes
        controller.setVolume(0.65)
        #expect(!controller.isMuted())
        #expect(abs(controller.getVolume() - 0.65) < 0.001)
    }

    @Test("AudioController toggleMute alternates and restores volume")
    func audioControllerToggleMuteCycles() {
        let controller = Edge.AudioController()
        let origVolume = controller.getVolume()
        let origMuted = controller.isMuted()
        defer {
            controller.setVolume(origVolume)
            if controller.isMuted() != origMuted {
                _ = controller.toggleMute()
            }
        }

        controller.setVolume(0.70)
        #expect(!controller.isMuted())

        // 1st toggle -> muted
        let muted1 = controller.toggleMute()
        #expect(muted1 == true)
        #expect(controller.isMuted() == true)

        // 2nd toggle -> unmuted, restores 0.70
        let muted2 = controller.toggleMute()
        #expect(muted2 == false)
        #expect(controller.isMuted() == false)
        #expect(abs(controller.getVolume() - 0.70) < 0.001)

        // 3rd toggle -> muted
        let muted3 = controller.toggleMute()
        #expect(muted3 == true)

        // 4th toggle -> unmuted
        let muted4 = controller.toggleMute()
        #expect(muted4 == false)
        #expect(abs(controller.getVolume() - 0.70) < 0.001)
    }

    @Test("AudioController un-muting with initial zero volume defaults to safe volume 0.25")
    func audioControllerUnmuteZeroVolumeDefault() {
        let controller = Edge.AudioController()
        let origVolume = controller.getVolume()
        let origMuted = controller.isMuted()
        defer {
            controller.setVolume(origVolume)
            if controller.isMuted() != origMuted {
                _ = controller.toggleMute()
            }
        }

        controller.setVolume(0.0)

        // Force mute
        if !controller.isMuted() {
            _ = controller.toggleMute()
        }

        // Un-mute
        _ = controller.toggleMute()
        #expect(!controller.isMuted())
        #expect(controller.getVolume() >= 0.25)
    }

    @Test("AudioController setVolumeListener receives updates")
    func audioControllerListenerNotification() {
        let controller = Edge.AudioController()
        let origVolume = controller.getVolume()
        let origMuted = controller.isMuted()
        defer {
            controller.setVolume(origVolume)
            if controller.isMuted() != origMuted {
                _ = controller.toggleMute()
            }
        }

        let receivedVolume = SendableBox<Float>(-1.0)
        let receivedMuted = SendableBox<Bool?>(nil)

        controller.setVolumeListener { vol, muted in
            receivedVolume.value = vol
            receivedMuted.value = muted
        }

        controller.setVolume(0.85)
        #expect(abs(receivedVolume.value - 0.85) < 0.001)
        #expect(receivedMuted.value == false)
    }

    @Test("AudioController adjustVolume and stepVolume increments")
    func audioControllerAdjustAndStep() {
        let controller = Edge.AudioController()
        let origVolume = controller.getVolume()
        let origMuted = controller.isMuted()
        defer {
            controller.setVolume(origVolume)
            if controller.isMuted() != origMuted {
                _ = controller.toggleMute()
            }
        }

        controller.setVolume(0.50)

        controller.adjustVolume(delta: 0.10)
        #expect(abs(controller.getVolume() - 0.60) < 0.001)

        controller.stepVolume(up: true, fine: false) // + 1/16 (0.0625)
        #expect(abs(controller.getVolume() - 0.6625) < 0.001)

        controller.stepVolume(up: false, fine: true) // - 1/64 (0.015625)
        #expect(abs(controller.getVolume() - (0.6625 - 0.015625)) < 0.001)
    }

    @Test("AudioController getAudioState reflects valid properties")
    func audioControllerGetAudioState() {
        let controller = Edge.AudioController()
        let state = controller.getAudioState()
        #expect(state.volume >= 0.0 && state.volume <= 1.0)
        #expect(!state.deviceName.isEmpty)
    }

    // MARK: - 2. BrightnessManager Unit Tests

    @Test("BrightnessManager conforms to BrightnessControlling")
    func brightnessManagerProtocolConformance() {
        let manager: any Edge.BrightnessControlling = Edge.BrightnessManager()
        #expect(manager.getBrightness() >= 0.0 && manager.getBrightness() <= 1.0)
    }

    @Test("BrightnessManager setBrightness clamps within [0.0, 1.0]")
    func brightnessManagerClamping() {
        let manager = Edge.BrightnessManager()
        let origBrightness = manager.getBrightness()
        defer {
            manager.setBrightness(origBrightness)
        }

        manager.setBrightness(1.8)
        #expect(manager.getBrightness() <= 1.0)

        manager.setBrightness(-0.3)
        #expect(manager.getBrightness() >= 0.0)

        manager.setBrightness(0.55)
        #expect(abs(manager.getBrightness() - 0.55) < 0.001)
    }

    @Test("BrightnessManager targetDisplayID resolves a valid display")
    func brightnessManagerTargetDisplayID() {
        let manager = Edge.BrightnessManager()
        let displayID = manager.targetDisplayID()
        #expect(displayID != 0)
    }

    @Test("BrightnessManager adjustBrightness and stepBrightness")
    func brightnessManagerAdjustAndStep() {
        let manager = Edge.BrightnessManager()
        let origBrightness = manager.getBrightness()
        defer {
            manager.setBrightness(origBrightness)
        }

        manager.setBrightness(0.50)

        let adj = manager.adjustBrightness(delta: 0.15)
        #expect(abs(adj - 0.65) < 0.001)

        let steppedUp = manager.stepBrightness(up: true, fine: false) // + 1/16 (0.0625)
        #expect(abs(steppedUp - 0.7125) < 0.001)

        let steppedDownFine = manager.stepBrightness(up: false, fine: true) // - 1/64 (0.015625)
        #expect(abs(steppedDownFine - (0.7125 - 0.015625)) < 0.001)
    }

    @Test("BrightnessManager handles non-finite NaN and Inf safely")
    func brightnessManagerNonFiniteSafety() {
        let manager = Edge.BrightnessManager()
        let origBrightness = manager.getBrightness()
        defer {
            manager.setBrightness(origBrightness)
        }

        manager.setBrightness(0.5)
        #expect(abs(manager.getBrightness() - 0.5) < 0.001)

        // Setting NaN should be rejected and leave cached brightness unchanged
        let nanResult = manager.setBrightness(Float.nan, displayID: manager.targetDisplayID())
        #expect(nanResult == false)
        #expect(manager.getBrightness().isFinite)
        #expect(abs(manager.getBrightness() - 0.5) < 0.001)

        // Setting infinity should be rejected
        let infResult = manager.setBrightness(Float.infinity, displayID: manager.targetDisplayID())
        #expect(infResult == false)
        #expect(manager.getBrightness().isFinite)

        // Adjusting with NaN delta should be safely ignored
        let adjNan = manager.adjustBrightness(delta: Float.nan)
        #expect(adjNan.isFinite)
    }

    // MARK: - 3. MediaManager Unit Tests

    @Test("MediaManager conforms to MediaControlling and triggers actions")
    func mediaManagerProtocolConformance() {
        let manager = Edge.MediaManager()
        let lastAction = SendableBox<Edge.MediaAction?>(nil)

        manager.onActionTriggered = { action in
            lastAction.value = action
        }

        manager.playPause()
        #expect(lastAction.value == .playPause)

        manager.nextTrack()
        #expect(lastAction.value == .nextTrack)

        manager.previousTrack()
        #expect(lastAction.value == .previousTrack)
    }

    @Test("MediaManager bottom edge swipe default direction")
    func mediaManagerSwipeDefault() {
        let manager = Edge.MediaManager()
        let lastAction = SendableBox<Edge.MediaAction?>(nil)

        manager.onActionTriggered = { action in
            lastAction.value = action
        }

        // Swipe right (deltaX > 0) -> Next track
        let rightAction = manager.handleBottomEdgeSwipe(deltaX: 25.0, reversed: false)
        #expect(rightAction == .nextTrack)
        #expect(lastAction.value == .nextTrack)

        // Swipe left (deltaX < 0) -> Previous track
        let leftAction = manager.handleBottomEdgeSwipe(deltaX: -25.0, reversed: false)
        #expect(leftAction == .previousTrack)
        #expect(lastAction.value == .previousTrack)

        // Zero delta -> Nil
        let zeroAction = manager.handleBottomEdgeSwipe(deltaX: 0.0, reversed: false)
        #expect(zeroAction == nil)
    }

    @Test("MediaManager bottom edge swipe reversed direction")
    func mediaManagerSwipeReversed() {
        let manager = Edge.MediaManager()
        let lastAction = SendableBox<Edge.MediaAction?>(nil)

        manager.onActionTriggered = { action in
            lastAction.value = action
        }

        // Swipe right (deltaX > 0) with reversed: true -> Previous track
        let rightAction = manager.handleBottomEdgeSwipe(deltaX: 30.0, reversed: true)
        #expect(rightAction == .previousTrack)
        #expect(lastAction.value == .previousTrack)

        // Swipe left (deltaX < 0) with reversed: true -> Next track
        let leftAction = manager.handleBottomEdgeSwipe(deltaX: -30.0, reversed: true)
        #expect(leftAction == .nextTrack)
        #expect(lastAction.value == .nextTrack)
    }

    @Test("MediaAction key types match system definitions")
    func mediaActionKeyTypes() {
        #expect(Edge.MediaAction.playPause.keyType == 16)
        #expect(Edge.MediaAction.nextTrack.keyType == 17)
        #expect(Edge.MediaAction.previousTrack.keyType == 18)
        #expect(Edge.MediaAction.fastForward.keyType == 19)
        #expect(Edge.MediaAction.rewind.keyType == 20)
    }

    // MARK: - 4. HUDManager & HUDWindowController Unit Tests

    @Test("HUDManager conforms to HUDManaging and updates state")
    func hudManagerConformanceAndState() {
        let manager = Edge.HUDManager()
        #expect(!manager.isVisible)

        // Volume
        manager.showVolume(level: 0.75, isMuted: false)
        #expect(manager.isVisible)
        #expect(manager.currentItem == .volume(level: 0.75, isMuted: false))

        // Brightness
        manager.showBrightness(level: 0.40)
        #expect(manager.isVisible)
        #expect(manager.currentItem == .brightness(level: 0.40))

        // Media
        manager.showMedia(action: .nextTrack)
        #expect(manager.isVisible)
        #expect(manager.currentItem == .media(action: .nextTrack))

        // Cancel timer during active drag
        manager.cancelDismissTimer()
        #expect(manager.isVisible)

        // Immediate dismiss
        manager.dismissImmediately()
        #expect(!manager.isVisible)
    }

    @Test("HUDWindowController configures non-activating floating panel")
    func hudWindowControllerConfiguration() {
        let manager = Edge.HUDManager()
        let controller = Edge.HUDWindowController(rootView: AnyView(Edge.HUDContainerView(manager: manager)))
        guard let panel = controller.panel else {
            Issue.record("Expected NSPanel to be initialized")
            return
        }

        #expect(panel.styleMask.contains(.borderless))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.level == .floating)
        #expect(panel.ignoresMouseEvents == true)
        #expect(panel.isOpaque == false)
        #expect(panel.backgroundColor == .clear)
        #expect(panel.hasShadow == false)
    }

    @Test("HUDWindowController positions centered above bottom edge")
    func hudWindowControllerPositioning() {
        let manager = Edge.HUDManager()
        let controller = Edge.HUDWindowController(rootView: AnyView(Edge.HUDContainerView(manager: manager)))
        guard let panel = controller.panel else {
            Issue.record("Expected NSPanel to be initialized")
            return
        }

        // Test positioning on dummy screen rect
        if let mainScreen = NSScreen.main ?? NSScreen.screens.first {
            controller.position(on: mainScreen)
            let frame = panel.frame
            let screenRect = mainScreen.frame

            #expect(frame.width == 260)
            #expect(frame.height == 56)
            #expect(abs(frame.midX - screenRect.midX) < 1.0)
            #expect(abs(frame.origin.y - (screenRect.origin.y + 140.0)) < 1.0)
        }
    }

    @Test("HUDWindowController mid-fade interruption preserves visibility")
    func hudWindowControllerMidFadeInterruption() async {
        let manager = Edge.HUDManager()
        let controller = Edge.HUDWindowController(rootView: AnyView(Edge.HUDContainerView(manager: manager)))
        guard let panel = controller.panel else {
            Issue.record("Expected NSPanel to be initialized")
            return
        }

        // Show initially
        controller.show()
        #expect(controller.isVisible == true)
        #expect(panel.alphaValue == 1.0)

        // Trigger fadeOut
        controller.fadeOut(duration: 0.2)

        // Interrupt immediately with show()
        controller.show()
        #expect(controller.isVisible == true)
        #expect(panel.alphaValue == 1.0)

        // Wait for the duration of the original fadeOut (0.2s + margin)
        try? await Task.sleep(nanoseconds: 250_000_000)

        // Panel must still be visible and not ordered out by the completed fadeOut animation
        #expect(controller.isVisible == true)
        #expect(panel.alphaValue == 1.0)

        // Cleanup
        controller.dismissImmediately()
        #expect(controller.isVisible == false)
    }

    @Test("SwiftUI HUD subviews instantiate cleanly")
    func swiftUIHUDViewsInstantiation() {
        let manager = Edge.HUDManager()
        let containerView = Edge.HUDContainerView(manager: manager)
        _ = containerView.body

        let volumeView = Edge.VolumeHUDView(level: 0.8, isMuted: false)
        _ = volumeView.body

        let mutedVolumeView = Edge.VolumeHUDView(level: 0.0, isMuted: true)
        _ = mutedVolumeView.body

        let brightnessView = Edge.BrightnessHUDView(level: 0.3)
        _ = brightnessView.body

        let mediaView = Edge.MediaHUDView(action: .playPause)
        _ = mediaView.body
    }
}
