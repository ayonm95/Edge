//
//  Tier3_CombinationTests.swift
//  EdgeTests
//
//  Tier 3: Cross-Feature Combinations & Concurrency Tests.
//  Validates multi-feature interactions, dynamic modifier transitions,
//  multi-edge touch arbitration, and concurrent preference updates.
//

import Foundation
import Testing

@Suite("Tier 3: Combination & Concurrency Tests")
struct Tier3_CombinationTests {

    // MARK: - Side Swapping + Sensitivity Multiplier

    @Test("T3.01: Side swapping with 2.0x sensitivity modulates volume on left edge at double speed")
    func testT3_01_SideSwapWithHighSensitivity() {
        let harness = TestHarness(initialVolume: 0.2, initialBrightness: 0.5)
        harness.updatePreferences {
            $0.swapSides = true
            $0.sensitivity = 2.0
        }
        harness.injectDrag(from: (0.05, 0.3), to: (0.05, 0.5), steps: 10)
        let delta = harness.audio.getVolume() - 0.2
        #expect(delta > 0.30)
        #expect(harness.brightness.getBrightness() == 0.5)
    }

    @Test("T3.02: Side swapping with 0.5x sensitivity modulates brightness on right edge at half speed")
    func testT3_02_SideSwapWithLowSensitivity() {
        let harness = TestHarness(initialVolume: 0.5, initialBrightness: 0.2)
        harness.updatePreferences {
            $0.swapSides = true
            $0.sensitivity = 0.5
        }
        harness.injectDrag(from: (0.95, 0.3), to: (0.95, 0.5), steps: 10)
        let delta = harness.brightness.getBrightness() - 0.2
        #expect(delta > 0 && delta < 0.15)
        #expect(harness.audio.getVolume() == 0.5)
    }

    // MARK: - Reverse Media Swipe + Double-Tap Play/Pause

    @Test("T3.03: Reverse media swipe with interleaved double-tap play/pause sequence")
    func testT3_03_ReverseMediaInterleavedSequence() {
        let harness = TestHarness()
        harness.updatePreferences { $0.reverseMediaSwipe = true }

        // 1. Swipe right (reversed -> previousTrack)
        harness.injectDrag(from: (0.3, 0.05), to: (0.6, 0.05), steps: 10, startTime: 10.0)

        // 2. Double tap (play/pause)
        harness.injectDoubleTap(at: (0.5, 0.05), startTime: 12.0)

        // 3. Swipe left (reversed -> nextTrack)
        harness.injectDrag(from: (0.6, 0.05), to: (0.3, 0.05), steps: 10, startTime: 14.0)

        let actions = harness.media.getActions()
        #expect(actions == [.previousTrack, .playPause, .nextTrack])
    }

    // MARK: - Volume Slide While Muted

    @Test("T3.04: Sliding volume upward while system is muted un-mutes automatically and raises volume")
    func testT3_04_VolumeSlideUnmutes() {
        let harness = TestHarness(initialVolume: 0.6)
        // Mute first via top-right double-tap
        harness.injectDoubleTap(at: (0.95, 0.95), startTime: 1.0)
        #expect(harness.audio.isMuted() == true)
        #expect(harness.audio.getVolume() == 0.0)

        // Slide upward on right edge
        harness.injectDrag(from: (0.95, 0.4), to: (0.95, 0.7), steps: 10, startTime: 3.0)
        #expect(harness.audio.isMuted() == false)
        #expect(harness.audio.getVolume() > 0.0)
    }

    // MARK: - Dynamic Mid-Drag Modifier Transition

    @Test("T3.05: Engaging Shift-Option mid-slide switches to micro-step scaling seamlessly")
    func testT3_05_MidSlideModifierTransition() {
        let harness = TestHarness(initialVolume: 0.1)

        // Start normal slide
        harness.injectTouch(x: 0.95, y: 0.2, phase: .makeTouch, timestamp: 1.0)
        harness.injectTouch(x: 0.95, y: 0.35, phase: .touching, timestamp: 1.1)
        let volAfterNormal = harness.audio.getVolume()

        // Engage Shift-Option
        harness.coordinator.gestureEngine.setShiftOptionModifier(true)
        harness.injectTouch(x: 0.95, y: 0.45, phase: .touching, timestamp: 1.2)
        let volAfterPrecise = harness.audio.getVolume()

        let normalStepDelta = volAfterNormal - 0.1
        let preciseStepDelta = volAfterPrecise - volAfterNormal
        #expect(preciseStepDelta < normalStepDelta * 0.7)

        // End gesture
        harness.injectTouch(x: 0.95, y: 0.45, phase: .breakTouch, timestamp: 1.3)
        harness.assertCursorFrozen(false)
    }

    // MARK: - Multi-Touch Edge Conflict Arbitration

    @Test("T3.06: Two fingers placed on opposite edges concurrently are rejected without corrupting state")
    func testT3_06_OppositeEdgeMultiTouchRejection() {
        let harness = TestHarness(initialVolume: 0.5, initialBrightness: 0.5)
        let t1 = SyntheticTouch(id: 1, position: MTPoint(x: 0.05, y: 0.5), phase: .touching)
        let t2 = SyntheticTouch(id: 2, position: MTPoint(x: 0.95, y: 0.5), phase: .touching)
        harness.coordinator.injectTouches([t1, t2])

        #expect(harness.cursor.isFrozen == false)
        #expect(harness.audio.getVolume() == 0.5)
        #expect(harness.brightness.getBrightness() == 0.5)
    }

    // MARK: - Concurrent Preference Updates Under Active Gesture Load

    @Test("T3.07: Concurrent preference mutation during high-frequency touch frames maintains thread safety")
    func testT3_07_ConcurrentPreferencesUnderLoad() async {
        let harness = TestHarness(initialVolume: 0.5)

        // Run background preference writer and foreground touch feeder concurrently
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Rapid preference updates
            group.addTask {
                for i in 0..<200 {
                    harness.updatePreferences {
                        $0.sensitivity = (i % 2 == 0) ? 1.0 : 2.0
                        $0.swapSides = (i % 4 == 0)
                        $0.edgeWidth = (i % 3 == 0) ? 0.08 : 0.12
                    }
                }
            }

            // Task 2: Rapid touch frames
            group.addTask {
                for i in 0..<200 {
                    let y = 0.3 + Float(i % 50) * 0.005
                    let phase: TouchPhase = (i == 0) ? .makeTouch : ((i == 199) ? .breakTouch : .touching)
                    harness.injectTouch(x: 0.95, y: y, phase: phase, timestamp: Double(i) * 0.008)
                }
            }
        }

        // Verify state is clean and no race corruptions occurred
        #expect(harness.audio.getVolume() >= 0.0 && harness.audio.getVolume() <= 1.0)
        #expect(harness.prefsHolder.get().edgeWidth >= 0.03)
    }

    // MARK: - HUD Debounce Cancellation Under Continuous Scrubbing

    @Test("T3.08: Continuous scrubbing for 3 seconds keeps HUD visible until finger lift")
    func testT3_08_HUDDebounceContinuousScrubbing() {
        let harness = TestHarness(initialVolume: 0.2)

        harness.injectTouch(x: 0.95, y: 0.2, phase: .makeTouch, timestamp: 0.0)
        for i in 1...30 {
            let t = Double(i) * 0.1 // 100ms intervals over 3 seconds
            let y = 0.2 + Float(i) * 0.015
            harness.injectTouch(x: 0.95, y: y, phase: .touching, timestamp: t)
            if i >= 2 {
                #expect(harness.hud.isDismissed == false)
                #expect(harness.hud.autoDismissScheduled == false)
            }
        }

        // Finger lifts
        harness.injectTouch(x: 0.95, y: 0.65, phase: .breakTouch, timestamp: 3.1)
        #expect(harness.hud.autoDismissScheduled == true)

        // Timer expires
        harness.hud.triggerAutoDismiss()
        #expect(harness.hud.isDismissed == true)
    }

    // MARK: - Active Area Restriction + Side Swapping

    @Test("T3.09: BottomHalf active area applies symmetrically when sides are swapped")
    func testT3_09_ActiveAreaWithSideSwap() {
        let harness = TestHarness(initialVolume: 0.5, initialBrightness: 0.5)
        harness.updatePreferences {
            $0.swapSides = true
            $0.activeArea = .bottomHalf
        }

        // Left edge now controls volume, but only in bottom half (y <= 0.5)
        // 1. Touch in upper half (y = 0.7): rejected
        harness.injectDrag(from: (0.05, 0.7), to: (0.05, 0.85), steps: 5, startTime: 1.0)
        #expect(harness.audio.getVolume() == 0.5)

        // 2. Touch in lower half (y = 0.3): accepted
        harness.injectDrag(from: (0.05, 0.3), to: (0.05, 0.45), steps: 5, startTime: 3.0)
        #expect(harness.audio.getVolume() > 0.5)
    }

    // MARK: - Rapid Quick Mute Alternation

    @Test("T3.10: 4 consecutive double-taps alternate mute and restore baseline volume reliably")
    func testT3_10_RapidMuteAlternation() {
        let harness = TestHarness(initialVolume: 0.72)

        // Cycle 1: Mute
        harness.injectDoubleTap(at: (0.95, 0.95), startTime: 1.0)
        #expect(harness.audio.isMuted() == true)
        #expect(harness.audio.getVolume() == 0.0)

        // Cycle 2: Unmute
        harness.injectDoubleTap(at: (0.95, 0.95), startTime: 2.0)
        #expect(harness.audio.isMuted() == false)
        harness.assertVolume(0.72)

        // Cycle 3: Mute again
        harness.injectDoubleTap(at: (0.95, 0.95), startTime: 3.0)
        #expect(harness.audio.isMuted() == true)
        #expect(harness.audio.getVolume() == 0.0)

        // Cycle 4: Unmute again
        harness.injectDoubleTap(at: (0.95, 0.95), startTime: 4.0)
        #expect(harness.audio.isMuted() == false)
        harness.assertVolume(0.72)
    }
}
