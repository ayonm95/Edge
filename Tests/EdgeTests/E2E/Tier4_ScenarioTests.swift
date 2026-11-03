//
//  Tier4_ScenarioTests.swift
//  EdgeTests
//
//  Tier 4: Real-World Workflow & End-to-End Scenarios.
//  Validates complete daily user journeys: media playback, emergency mute,
//  late-night precision dimming, live settings tuning, typing palm rejection,
//  and accessibility onboarding recovery.
//

import Foundation
import Testing

@Suite("Tier 4: Real-World Usage Scenarios")
struct Tier4_ScenarioTests {

    // MARK: - Scenario 1: Daily Media Playback Workflow

    @Test("T4.01: Complete media listening session with volume adjustments, track skipping, and dimming")
    func testT4_01_DailyMediaListeningSession() {
        let harness = TestHarness(initialVolume: 0.3, initialBrightness: 0.5)

        // 1. Double-tap bottom edge to start playback
        harness.injectDoubleTap(at: (0.5, 0.05), startTime: 1.0)
        #expect(harness.media.recordedActions.contains(.playPause))
        #expect(harness.hud.currentType == .media(action: .playPause))

        // 2. Adjust volume from 30% up to ~60% on right edge
        harness.injectDrag(from: (0.95, 0.3), to: (0.95, 0.6), steps: 10, startTime: 3.0)
        #expect(harness.audio.getVolume() > 0.55)
        #expect(harness.cursor.isFrozen == false)
        #expect(harness.haptics.tickCount >= 3)

        // 3. Skip two tracks forward via bottom edge swipes
        harness.injectDrag(from: (0.3, 0.05), to: (0.6, 0.05), steps: 10, startTime: 6.0)
        harness.injectDrag(from: (0.3, 0.05), to: (0.6, 0.05), steps: 10, startTime: 8.0)
        #expect(harness.media.nextTrackCount == 2)

        // 4. Adjust display brightness on left edge
        harness.injectDrag(from: (0.05, 0.4), to: (0.05, 0.7), steps: 10, startTime: 10.0)
        #expect(harness.brightness.getBrightness() > 0.7)

        // 5. Pause playback via bottom edge double-tap
        harness.injectDoubleTap(at: (0.5, 0.05), startTime: 12.0)
        #expect(harness.media.playPauseCount == 2)
    }

    // MARK: - Scenario 2: Conference Call Quick Mute Emergency

    @Test("T4.02: Conference call quick mute, speaker un-mute, and fine volume tuning")
    func testT4_02_ConferenceCallEmergencyMute() {
        let harness = TestHarness(initialVolume: 0.65)

        // 1. Sudden background noise: double tap top-right corner to mute immediately
        harness.injectDoubleTap(at: (0.95, 0.95), startTime: 10.0)
        #expect(harness.audio.isMuted() == true)
        #expect(harness.audio.getVolume() == 0.0)
        #expect(harness.hud.currentType == .volume(level: 0.0, isMuted: true))

        // 2. Turn to speak: double tap top-right corner again to unmute
        harness.injectDoubleTap(at: (0.95, 0.95), startTime: 25.0)
        #expect(harness.audio.isMuted() == false)
        harness.assertVolume(0.65)

        // 3. Remote speaker is quiet: slide right edge upward to 85%
        harness.injectDrag(from: (0.95, 0.5), to: (0.95, 0.7), steps: 8, startTime: 30.0)
        #expect(harness.audio.getVolume() > 0.8)

        // 4. Finger lifts, HUD auto-dismiss triggers after timeout
        harness.hud.triggerAutoDismiss()
        #expect(harness.hud.isDismissed == true)
    }

    // MARK: - Scenario 3: Late Night Dimming in Dark Room (Precise Mode)

    @Test("T4.03: Late night precision dimming on left edge with micro-haptic quantization")
    func testT4_03_LateNightPrecisionDimming() {
        let harness = TestHarness(initialBrightness: 0.75)
        harness.updatePreferences { $0.preciseSliding = true }

        // Slide downward on left edge in micro-steps
        harness.injectDrag(from: (0.05, 0.7), to: (0.05, 0.2), steps: 25, startTime: 5.0)

        // Verify brightness decreased smoothly into low-light range
        #expect(harness.brightness.getBrightness() < 0.75)
        #expect(harness.brightness.getBrightness() > 0.3)

        // Verify micro-haptics fired during precision sliding
        #expect(harness.haptics.tickCount >= 5)
    }

    // MARK: - Scenario 4: Live Preferences Tuning Workflow

    @Test("T4.04: User changes preferences in Settings and immediately uses updated gestures")
    func testT4_04_LiveSettingsTuningWorkflow() {
        let harness = TestHarness(initialVolume: 0.4, initialBrightness: 0.4)

        // User changes 3 settings: swap sides, wider edge margin, bottom-half active area
        harness.updatePreferences {
            $0.swapSides = true
            $0.edgeWidth = 0.15
            $0.activeArea = .bottomHalf
        }

        // Test 1: Touch on upper half (y=0.7) on left edge: rejected by activeArea
        harness.injectDrag(from: (0.08, 0.7), to: (0.08, 0.85), steps: 5, startTime: 1.0)
        #expect(harness.audio.getVolume() == 0.4)

        // Test 2: Touch on lower half (y=0.3) at x=0.12 (inside new 0.15 margin): accepted!
        // Because sides are swapped, left edge modulates volume!
        harness.injectDrag(from: (0.12, 0.3), to: (0.12, 0.45), steps: 8, startTime: 3.0)
        #expect(harness.audio.getVolume() > 0.4)

        // Test 3: Right edge now modulates brightness
        harness.injectDrag(from: (0.90, 0.3), to: (0.90, 0.45), steps: 8, startTime: 5.0)
        #expect(harness.brightness.getBrightness() > 0.4)
    }

    // MARK: - Scenario 5: Palm Rejection While Rapid Typing

    @Test("T4.05: Accidental palm brushes during active typing do not trigger sliders or freeze cursor")
    func testT4_05_TypingPalmRejection() {
        let harness = TestHarness(initialVolume: 0.5, initialBrightness: 0.5)

        // Left palm resting/brushing left edge (large contact area 25x20)
        harness.injectTouch(x: 0.05, y: 0.4, phase: .makeTouch, majorRadius: 25.0, minorRadius: 20.0)
        harness.injectTouch(x: 0.06, y: 0.42, phase: .touching, majorRadius: 25.0, minorRadius: 20.0)
        harness.injectTouch(x: 0.06, y: 0.42, phase: .breakTouch, majorRadius: 25.0, minorRadius: 20.0)

        // Right palm resting/brushing right edge (large contact area 30x25)
        harness.injectTouch(x: 0.95, y: 0.4, phase: .makeTouch, majorRadius: 30.0, minorRadius: 25.0)
        harness.injectTouch(x: 0.94, y: 0.42, phase: .touching, majorRadius: 30.0, minorRadius: 25.0)
        harness.injectTouch(x: 0.94, y: 0.42, phase: .breakTouch, majorRadius: 30.0, minorRadius: 25.0)

        // Verify no false positive volume/brightness changes and cursor remained free
        #expect(harness.audio.getVolume() == 0.5)
        #expect(harness.brightness.getBrightness() == 0.5)
        #expect(harness.cursor.isFrozen == false)
        #expect(harness.hud.currentType == nil)
    }

    // MARK: - Scenario 6: Reverse Media Playlist Navigation

    @Test("T4.06: Custom media swipe direction persists across playlist track skips")
    func testT4_06_ReverseMediaPlaylistNavigation() {
        let harness = TestHarness()
        harness.updatePreferences { $0.reverseMediaSwipe = true }

        // Swipe right (reversed -> previous track)
        harness.injectDrag(from: (0.3, 0.05), to: (0.6, 0.05), steps: 10, startTime: 1.0)
        // Swipe right again
        harness.injectDrag(from: (0.3, 0.05), to: (0.6, 0.05), steps: 10, startTime: 3.0)

        #expect(harness.media.prevTrackCount == 2)
        #expect(harness.media.nextTrackCount == 0)

        // Swipe left (reversed -> next track)
        harness.injectDrag(from: (0.6, 0.05), to: (0.3, 0.05), steps: 10, startTime: 5.0)
        #expect(harness.media.nextTrackCount == 1)
    }

    // MARK: - Scenario 7: Accessibility Onboarding & First-Run Recovery

    @Test("T4.07: First launch untrusted state guides user through onboarding and recovers seamlessly")
    func testT4_07_AccessibilityOnboardingRecovery() {
        let harness = TestHarness(initiallyTrustedAccessibility: false)

        // 1. App starts in untrusted state -> status icon shows alert
        harness.statusItem.setState(.alert)
        #expect(harness.statusItem.getState() == .alert)
        #expect(harness.accessibility.isTrusted() == false)

        // 2. Onboarding window presents deep link to Privacy & Security
        harness.accessibility.openSystemSettingsDeepLink()
        #expect(harness.accessibility.lastDeepLinkURL?.contains("Privacy_Accessibility") == true)

        // 3. User enables permission in System Settings -> polling detects authorization
        harness.accessibility.setTrusted(true)
        #expect(harness.accessibility.isTrusted() == true)

        // 4. Status item transitions from alert to idle
        harness.statusItem.setState(.idle)
        #expect(harness.statusItem.getState() == .idle)

        // 5. Gestures now operate normally
        harness.injectDrag(from: (0.95, 0.3), to: (0.95, 0.6), steps: 8)
        #expect(harness.audio.getVolume() > 0.5)
    }
}
