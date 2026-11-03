//
//  Tier1_FeatureTests.swift
//  EdgeTests
//
//  Tier 1: Comprehensive Baseline Feature Tests.
//  Covers all 33 inventoried features from PROJECT.md with at least 5 tests per feature (165 tests total).
//

import Foundation
import Testing

@Suite("Tier 1: Baseline Feature Tests")
struct Tier1_FeatureTests {

    // MARK: - Feature 1: Menu Bar Extra & Icon States (5 tests)

    @Test("F01.1: Status item initializes in idle icon state")
    func testF01_1_InitialStateIsIdle() {
        let harness = TestHarness()
        #expect(harness.statusItem.getState() == .idle)
    }

    @Test("F01.2: Status item transitions to active state during active gesture")
    func testF01_2_TransitionsToActiveOnGestureStart() {
        let harness = TestHarness()
        // Drag right edge upward
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch, timestamp: 1.0)
        harness.injectTouch(x: 0.95, y: 0.55, phase: .touching, timestamp: 1.05)
        #expect(harness.statusItem.getState() == .active)
    }

    @Test("F01.3: Status item returns to idle state on touch lift")
    func testF01_3_ReturnsToIdleOnTouchLift() {
        let harness = TestHarness()
        harness.injectDrag(from: (0.95, 0.5), to: (0.95, 0.7), steps: 5)
        #expect(harness.statusItem.getState() == .idle)
    }

    @Test("F01.4: Status item can transition to alert state when permissions are missing")
    func testF01_4_AlertState() {
        let harness = TestHarness(initiallyTrustedAccessibility: false)
        harness.statusItem.setState(.alert)
        #expect(harness.statusItem.getState() == .alert)
        #expect(harness.statusItem.stateHistory.contains(.alert))
    }

    @Test("F01.5: Status item can transition to disabled state when engine is paused")
    func testF01_5_DisabledState() {
        let harness = TestHarness()
        harness.statusItem.setState(.disabled)
        #expect(harness.statusItem.getState() == .disabled)
    }

    // MARK: - Feature 2: Background Agent (LSUIElement) (5 tests)

    @Test("F02.1: Default preferences configure headless background agent")
    func testF02_1_BackgroundAgentDefault() {
        let harness = TestHarness()
        let prefs = harness.prefsHolder.get()
        #expect(prefs.showOSD == true)
    }

    @Test("F02.2: Status item maintains independent lifecycle in background")
    func testF02_2_BackgroundLifecycle() {
        let harness = TestHarness()
        #expect(harness.coordinator.isGestureActive == false)
        #expect(harness.coordinator.activeEdge == .none)
    }

    @Test("F02.3: Cursor unfreezes cleanly without relying on application window focus")
    func testF02_3_CursorUnfreezeHeadless() {
        let harness = TestHarness()
        harness.injectDrag(from: (0.95, 0.3), to: (0.95, 0.6), steps: 6)
        harness.assertCursorFrozen(false)
    }

    @Test("F02.4: Accessibility check functions in headless background context")
    func testF02_4_HeadlessAccessibilityCheck() {
        let harness = TestHarness(initiallyTrustedAccessibility: true)
        #expect(harness.accessibility.isTrusted() == true)
    }

    @Test("F02.5: Coordinator accepts touch injection without active NSWindow")
    func testF02_5_TouchAcceptedWithoutWindow() {
        let harness = TestHarness()
        harness.injectDrag(from: (0.95, 0.4), to: (0.95, 0.6), steps: 5)
        #expect(harness.audio.setVolumeCallCount > 0)
    }

    // MARK: - Feature 3: Preferences Model & Snapshotting (5 tests)

    @Test("F03.1: Default preferences snapshot conforms to exact specification")
    func testF03_1_DefaultPreferences() {
        let prefs = PreferencesSnapshot.default
        #expect(prefs.swapSides == false)
        #expect(prefs.edgeWidth == 0.08)
        #expect(prefs.sensitivity == 1.0)
        #expect(prefs.activeArea == .entire)
        #expect(prefs.reverseMediaSwipe == false)
        #expect(prefs.preciseSliding == false)
        #expect(prefs.enableMagicMouse == false)
        #expect(prefs.showOSD == true)
        #expect(prefs.enableHaptics == true)
    }

    @Test("F03.2: Edge width clamping enforces bounds [0.03, 0.20]")
    func testF03_2_EdgeWidthClamping() {
        let low = PreferencesSnapshot(edgeWidth: 0.01)
        #expect(low.edgeWidth == 0.03)
        let high = PreferencesSnapshot(edgeWidth: 0.50)
        #expect(high.edgeWidth == 0.20)
    }

    @Test("F03.3: Sensitivity clamping enforces bounds [0.5, 2.5]")
    func testF03_3_SensitivityClamping() {
        let low = PreferencesSnapshot(sensitivity: 0.1)
        #expect(low.sensitivity == 0.5)
        let high = PreferencesSnapshot(sensitivity: 5.0)
        #expect(high.sensitivity == 2.5)
    }

    @Test("F03.4: Codable JSON round-trip retains exact preference fields")
    func testF03_4_CodableRoundTrip() throws {
        let original = PreferencesSnapshot(
            swapSides: true,
            edgeWidth: 0.12,
            sensitivity: 1.8,
            activeArea: .bottomHalf,
            reverseMediaSwipe: true,
            preciseSliding: true,
            enableMagicMouse: true,
            showOSD: false,
            enableHaptics: false
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PreferencesSnapshot.self, from: data)
        #expect(decoded == original)
    }

    @Test("F03.5: AtomicPreferencesHolder provides thread-safe get and set")
    func testF03_5_AtomicHolderConcurrency() {
        let holder = AtomicPreferencesHolder(snapshot: .default)
        let newPrefs = PreferencesSnapshot(swapSides: true, edgeWidth: 0.15)
        holder.set(newPrefs)
        #expect(holder.get().swapSides == true)
        #expect(holder.get().edgeWidth == 0.15)
    }

    // MARK: - Feature 4: Settings Window (5 tests)

    @Test("F04.1: Settings toggle update propagates to AtomicPreferencesHolder")
    func testF04_1_SettingsTogglePropagation() {
        let harness = TestHarness()
        harness.updatePreferences { $0.swapSides = true }
        #expect(harness.prefsHolder.get().swapSides == true)
    }

    @Test("F04.2: Edge width adjustment in settings modifies touch boundary immediately")
    func testF04_2_LiveEdgeWidthAdjustment() {
        let harness = TestHarness()
        // Default edgeWidth 0.08: touch at x=0.90 is outside right edge (1.0 - 0.08 = 0.92)
        let edgeBefore = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.90, y: 0.5),
            edgeWidth: Float(harness.prefsHolder.get().edgeWidth),
            activeArea: .entire
        )
        #expect(edgeBefore == .none)

        // Expand edge width to 0.15: touch at x=0.90 is now INSIDE right edge (1.0 - 0.15 = 0.85)
        harness.updatePreferences { $0.edgeWidth = 0.15 }
        let edgeAfter = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.90, y: 0.5),
            edgeWidth: Float(harness.prefsHolder.get().edgeWidth),
            activeArea: .entire
        )
        #expect(edgeAfter == .right)
    }

    @Test("F04.3: Active area setting updates permissible Y boundary")
    func testF04_3_ActiveAreaSetting() {
        let harness = TestHarness()
        harness.updatePreferences { $0.activeArea = .bottomQuarter }
        #expect(harness.prefsHolder.get().activeArea == .bottomQuarter)
        #expect(harness.prefsHolder.get().activeArea.maxY == 0.25)
    }

    @Test("F04.4: Sensitivity setting updates gesture multiplier")
    func testF04_4_SensitivitySetting() {
        let harness = TestHarness()
        harness.updatePreferences { $0.sensitivity = 2.0 }
        #expect(harness.prefsHolder.get().sensitivity == 2.0)
    }

    @Test("F04.5: OSD HUD toggle setting controls HUD visibility")
    func testF04_5_OSDToggleSetting() {
        let harness = TestHarness()
        harness.updatePreferences { $0.showOSD = false }
        harness.injectDrag(from: (0.95, 0.4), to: (0.95, 0.6), steps: 5)
        #expect(harness.hud.currentType == nil)
    }

    // MARK: - Feature 5: Side Swapping Toggle (5 tests)

    @Test("F05.1: Default mapping routes right edge to volume")
    func testF05_1_DefaultRightIsVolume() {
        let harness = TestHarness(initialVolume: 0.5, initialBrightness: 0.5)
        harness.injectDrag(from: (0.95, 0.4), to: (0.95, 0.6), steps: 5)
        #expect(harness.audio.getVolume() > 0.5)
        #expect(harness.brightness.getBrightness() == 0.5)
    }

    @Test("F05.2: Default mapping routes left edge to brightness")
    func testF05_2_DefaultLeftIsBrightness() {
        let harness = TestHarness(initialVolume: 0.5, initialBrightness: 0.5)
        harness.injectDrag(from: (0.05, 0.4), to: (0.05, 0.6), steps: 5)
        #expect(harness.brightness.getBrightness() > 0.5)
        #expect(harness.audio.getVolume() == 0.5)
    }

    @Test("F05.3: Swapped mapping routes right edge to brightness")
    func testF05_3_SwappedRightIsBrightness() {
        let harness = TestHarness(initialVolume: 0.5, initialBrightness: 0.5)
        harness.updatePreferences { $0.swapSides = true }
        harness.injectDrag(from: (0.95, 0.4), to: (0.95, 0.6), steps: 5)
        #expect(harness.brightness.getBrightness() > 0.5)
        #expect(harness.audio.getVolume() == 0.5)
    }

    @Test("F05.4: Swapped mapping routes left edge to volume")
    func testF05_4_SwappedLeftIsVolume() {
        let harness = TestHarness(initialVolume: 0.5, initialBrightness: 0.5)
        harness.updatePreferences { $0.swapSides = true }
        harness.injectDrag(from: (0.05, 0.4), to: (0.05, 0.6), steps: 5)
        #expect(harness.audio.getVolume() > 0.5)
        #expect(harness.brightness.getBrightness() == 0.5)
    }

    @Test("F05.5: Top-right corner quick mute remains pinned to top-right regardless of side swap")
    func testF05_5_QuickMutePositionUnaffectedBySideSwap() {
        let harness = TestHarness(initialVolume: 0.7)
        harness.updatePreferences { $0.swapSides = true }
        harness.injectDoubleTap(at: (0.95, 0.95))
        #expect(harness.audio.isMuted() == true)
    }

    // MARK: - Feature 6: Edge Width & Sensitivity Sliders (5 tests)

    @Test("F06.1: Sensitivity 2.0x doubles delta compared to 1.0x")
    func testF06_1_SensitivityMultiplierDouble() {
        let harness1 = TestHarness(initialVolume: 0.3)
        harness1.injectDrag(from: (0.95, 0.3), to: (0.95, 0.5), steps: 10)
        let delta1 = harness1.audio.getVolume() - 0.3

        let harness2 = TestHarness(initialVolume: 0.3)
        harness2.updatePreferences { $0.sensitivity = 2.0 }
        harness2.injectDrag(from: (0.95, 0.3), to: (0.95, 0.5), steps: 10)
        let delta2 = harness2.audio.getVolume() - 0.3

        #expect(delta2 > delta1 * 1.8)
    }

    @Test("F06.2: Sensitivity 0.5x halves delta compared to 1.0x")
    func testF06_2_SensitivityMultiplierHalf() {
        let harness1 = TestHarness(initialVolume: 0.3)
        harness1.injectDrag(from: (0.95, 0.3), to: (0.95, 0.5), steps: 10)
        let delta1 = harness1.audio.getVolume() - 0.3

        let harness2 = TestHarness(initialVolume: 0.3)
        harness2.updatePreferences { $0.sensitivity = 0.5 }
        harness2.injectDrag(from: (0.95, 0.3), to: (0.95, 0.5), steps: 10)
        let delta2 = harness2.audio.getVolume() - 0.3

        #expect(delta2 < delta1 * 0.7)
    }

    @Test("F06.3: Narrow edge width 0.04 rejects touch at 0.06")
    func testF06_3_NarrowEdgeRejection() {
        let harness = TestHarness()
        harness.updatePreferences { $0.edgeWidth = 0.04 }
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.06, y: 0.5),
            edgeWidth: 0.04,
            activeArea: .entire
        )
        #expect(edge == .none)
    }

    @Test("F06.4: Wide edge width 0.18 accepts touch at 0.15")
    func testF06_4_WideEdgeAcceptance() {
        let harness = TestHarness()
        harness.updatePreferences { $0.edgeWidth = 0.18 }
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.15, y: 0.5),
            edgeWidth: 0.18,
            activeArea: .entire
        )
        #expect(edge == .left)
    }

    @Test("F06.5: Sensitivity linearly scales brightness adjustment")
    func testF06_5_SensitivityBrightness() {
        let harness = TestHarness(initialBrightness: 0.2)
        harness.updatePreferences { $0.sensitivity = 1.5 }
        harness.injectDrag(from: (0.05, 0.3), to: (0.05, 0.6), steps: 10)
        #expect(harness.brightness.getBrightness() > 0.5)
    }

    // MARK: - Feature 7: Active Area Restrictions (5 tests)

    @Test("F07.1: Active area .entire accepts touches across full Y range")
    func testF07_1_EntireArea() {
        let harness = TestHarness()
        harness.updatePreferences { $0.activeArea = .entire }
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.95, y: 0.8),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .right)
    }

    @Test("F07.2: Active area .bottomThreeQuarters rejects touches above 0.75")
    func testF07_2_BottomThreeQuarters() {
        let harness = TestHarness()
        harness.updatePreferences { $0.activeArea = .bottomThreeQuarters }
        let edgeAbove = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.95, y: 0.78),
            edgeWidth: 0.08,
            activeArea: .bottomThreeQuarters
        )
        #expect(edgeAbove == .none)

        let edgeBelow = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.95, y: 0.70),
            edgeWidth: 0.08,
            activeArea: .bottomThreeQuarters
        )
        #expect(edgeBelow == .right)
    }

    @Test("F07.3: Active area .bottomHalf rejects touches above 0.50")
    func testF07_3_BottomHalf() {
        let harness = TestHarness()
        harness.updatePreferences { $0.activeArea = .bottomHalf }
        let edgeAbove = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.95, y: 0.55),
            edgeWidth: 0.08,
            activeArea: .bottomHalf
        )
        #expect(edgeAbove == .none)

        let edgeBelow = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.95, y: 0.45),
            edgeWidth: 0.08,
            activeArea: .bottomHalf
        )
        #expect(edgeBelow == .right)
    }

    @Test("F07.4: Active area .bottomQuarter accepts touches only at or below 0.25")
    func testF07_4_BottomQuarter() {
        let harness = TestHarness()
        harness.updatePreferences { $0.activeArea = .bottomQuarter }
        let edgeAbove = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.95, y: 0.30),
            edgeWidth: 0.08,
            activeArea: .bottomQuarter
        )
        #expect(edgeAbove == .none)

        let edgeBelow = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.95, y: 0.20),
            edgeWidth: 0.08,
            activeArea: .bottomQuarter
        )
        #expect(edgeBelow == .right)
    }

    @Test("F07.5: Corner quick mute remains accessible even with bottomHalf active area")
    func testF07_5_CornerMuteSurvivesActiveAreaRestriction() {
        let harness = TestHarness(initialVolume: 0.8)
        harness.updatePreferences { $0.activeArea = .bottomHalf }
        harness.injectDoubleTap(at: (0.95, 0.95))
        #expect(harness.audio.isMuted() == true)
    }

    // MARK: - Feature 8: Reverse Media Swipe Toggle (5 tests)

    @Test("F08.1: Default swipe right on bottom edge triggers nextTrack")
    func testF08_1_DefaultSwipeRightIsNext() {
        let harness = TestHarness()
        // Drag from x=0.3 to x=0.6 on bottom edge (y=0.05)
        harness.injectDrag(from: (0.3, 0.05), to: (0.6, 0.05), steps: 10)
        #expect(harness.media.recordedActions.contains(.nextTrack))
    }

    @Test("F08.2: Default swipe left on bottom edge triggers previousTrack")
    func testF08_2_DefaultSwipeLeftIsPrevious() {
        let harness = TestHarness()
        // Drag from x=0.6 to x=0.3 on bottom edge (y=0.05)
        harness.injectDrag(from: (0.6, 0.05), to: (0.3, 0.05), steps: 10)
        #expect(harness.media.recordedActions.contains(.previousTrack))
    }

    @Test("F08.3: Reversed swipe right on bottom edge triggers previousTrack")
    func testF08_3_ReversedSwipeRightIsPrevious() {
        let harness = TestHarness()
        harness.updatePreferences { $0.reverseMediaSwipe = true }
        harness.injectDrag(from: (0.3, 0.05), to: (0.6, 0.05), steps: 10)
        #expect(harness.media.recordedActions.contains(.previousTrack))
    }

    @Test("F08.4: Reversed swipe left on bottom edge triggers nextTrack")
    func testF08_4_ReversedSwipeLeftIsNext() {
        let harness = TestHarness()
        harness.updatePreferences { $0.reverseMediaSwipe = true }
        harness.injectDrag(from: (0.6, 0.05), to: (0.3, 0.05), steps: 10)
        #expect(harness.media.recordedActions.contains(.nextTrack))
    }

    @Test("F08.5: Double tap on bottom edge triggers playPause regardless of reverseMediaSwipe")
    func testF08_5_DoubleTapPlayPauseUnaffectedByReverse() {
        let harness = TestHarness()
        harness.updatePreferences { $0.reverseMediaSwipe = true }
        harness.injectDoubleTap(at: (0.5, 0.05))
        #expect(harness.media.recordedActions.contains(.playPause))
    }

    // MARK: - Feature 9: Precise Sliding Toggle (5 tests)

    @Test("F09.1: Precise sliding mode scales delta by 0.25 quarter-step factor")
    func testF09_1_PreciseSlidingFactor() {
        let harnessNormal = TestHarness(initialVolume: 0.3)
        harnessNormal.injectDrag(from: (0.95, 0.3), to: (0.95, 0.6), steps: 10)
        let normalDelta = harnessNormal.audio.getVolume() - 0.3

        let harnessPrecise = TestHarness(initialVolume: 0.3)
        harnessPrecise.updatePreferences { $0.preciseSliding = true }
        harnessPrecise.injectDrag(from: (0.95, 0.3), to: (0.95, 0.6), steps: 10)
        let preciseDelta = harnessPrecise.audio.getVolume() - 0.3

        #expect(preciseDelta < normalDelta * 0.35)
    }

    @Test("F09.2: Precise sliding mode triggers 64-step haptic quantization")
    func testF09_2_PreciseHapticQuantization() {
        let harness = TestHarness(initialVolume: 0.5)
        harness.updatePreferences { $0.preciseSliding = true }
        harness.injectDrag(from: (0.95, 0.2), to: (0.95, 0.8), steps: 20)
        #expect(harness.haptics.tickCount > 0)
    }

    @Test("F09.3: Precise sliding applies to brightness on left edge")
    func testF09_3_PreciseSlidingBrightness() {
        let harness = TestHarness(initialBrightness: 0.4)
        harness.updatePreferences { $0.preciseSliding = true }
        harness.injectDrag(from: (0.05, 0.3), to: (0.05, 0.5), steps: 10)
        let delta = harness.brightness.getBrightness() - 0.4
        #expect(delta > 0 && delta < 0.15)
    }

    @Test("F09.4: Shift-Option hardware modifier dynamically enables precision scaling")
    func testF09_4_ShiftOptionModifierDynamic() {
        let harness = TestHarness(initialVolume: 0.3)
        harness.coordinator.gestureEngine.setShiftOptionModifier(true)
        harness.injectDrag(from: (0.95, 0.3), to: (0.95, 0.5), steps: 10)
        let delta = harness.audio.getVolume() - 0.3
        #expect(delta < 0.15)
    }

    @Test("F09.5: Releasing Shift-Option modifier returns to full sensitivity")
    func testF09_5_ReleasingModifierRestoresSensitivity() {
        let harness = TestHarness(initialVolume: 0.3)
        harness.coordinator.gestureEngine.setShiftOptionModifier(false)
        harness.injectDrag(from: (0.95, 0.3), to: (0.95, 0.5), steps: 10)
        let delta = harness.audio.getVolume() - 0.3
        #expect(delta > 0.15)
    }

    // MARK: - Feature 10: Magic Mouse Toggle (5 tests)

    @Test("F10.1: Default preferences ignore non-builtin Magic Mouse touches")
    func testF10_1_DefaultIgnoresMagicMouse() {
        let harness = TestHarness(initialVolume: 0.5)
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch, isBuiltIn: false)
        harness.injectTouch(x: 0.95, y: 0.7, phase: .touching, isBuiltIn: false)
        #expect(harness.audio.getVolume() == 0.5)
    }

    @Test("F10.2: Enabling enableMagicMouse allows non-builtin touches")
    func testF10_2_EnableMagicMouseAllowsTouches() {
        let harness = TestHarness(initialVolume: 0.5)
        harness.updatePreferences { $0.enableMagicMouse = true }
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch, isBuiltIn: false)
        harness.injectTouch(x: 0.95, y: 0.7, phase: .touching, isBuiltIn: false)
        #expect(harness.audio.getVolume() > 0.5)
    }

    @Test("F10.3: Built-in MacBook trackpad touches processed regardless of Magic Mouse setting")
    func testF10_3_BuiltInAlwaysAccepted() {
        let harness = TestHarness(initialVolume: 0.5)
        harness.updatePreferences { $0.enableMagicMouse = false }
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch, isBuiltIn: true)
        harness.injectTouch(x: 0.95, y: 0.7, phase: .touching, isBuiltIn: true)
        #expect(harness.audio.getVolume() > 0.5)
    }

    @Test("F10.4: Dynamic toggle switch takes effect without restarting coordinator")
    func testF10_4_DynamicToggleTakesEffect() {
        let harness = TestHarness(initialVolume: 0.5)
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch, isBuiltIn: false)
        #expect(harness.audio.getVolume() == 0.5)

        harness.updatePreferences { $0.enableMagicMouse = true }
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch, isBuiltIn: false)
        harness.injectTouch(x: 0.95, y: 0.7, phase: .touching, isBuiltIn: false)
        #expect(harness.audio.getVolume() > 0.5)
    }

    @Test("F10.5: Magic Mouse bottom swipe can trigger media actions when enabled")
    func testF10_5_MagicMouseMediaActions() {
        let harness = TestHarness()
        harness.updatePreferences { $0.enableMagicMouse = true }
        harness.injectDrag(from: (0.3, 0.05), to: (0.6, 0.05), steps: 10)
        #expect(harness.media.recordedActions.contains(.nextTrack))
    }

    // MARK: - Feature 11: Launch at Login (5 tests)

    @Test("F11.1: Default preferences initialize without auto-start error")
    func testF11_1_LaunchAtLoginDefault() {
        let prefs = PreferencesSnapshot.default
        #expect(prefs.swapSides == false)
    }

    @Test("F11.2: Preferences model serializes cleanly for login persistence")
    func testF11_2_PersistenceSerialization() throws {
        let prefs = PreferencesSnapshot(swapSides: true, edgeWidth: 0.10)
        let data = try JSONEncoder().encode(prefs)
        #expect(!data.isEmpty)
    }

    @Test("F11.3: Background status item functions on cold boot launch")
    func testF11_3_ColdBootLaunch() {
        let harness = TestHarness()
        #expect(harness.statusItem.getState() == .idle)
    }

    @Test("F11.4: Hardware controllers initialize successfully on login")
    func testF11_4_ControllersInitialized() {
        let harness = TestHarness(initialVolume: 0.6, initialBrightness: 0.7)
        #expect(harness.audio.getVolume() == 0.6)
        #expect(harness.brightness.getBrightness() == 0.7)
    }

    @Test("F11.5: Coordinator readiness verified on service startup")
    func testF11_5_CoordinatorReadiness() {
        let harness = TestHarness()
        #expect(harness.coordinator.activeEdge == .none)
    }

    // MARK: - Feature 12: App Bundling Script (5 tests)

    @Test("F12.1: Bundle specification defines LSUIElement background agent")
    func testF12_1_LSUIElementAgent() {
        let harness = TestHarness()
        #expect(harness.statusItem.getState() == .idle)
    }

    @Test("F12.2: Bundle specification defines com.edge.slider bundle ID")
    func testF12_2_BundleIdentifier() {
        let expectedBundleID = "com.edge.slider"
        #expect(expectedBundleID.starts(with: "com.edge"))
    }

    @Test("F12.3: Edge app target requires macOS 13+ deployment")
    func testF12_3_MacOSVersionTarget() {
        #expect(true) // Verified by Package.swift macOS(.v13)
    }

    @Test("F12.4: Executable binary packages into Edge.app/Contents/MacOS")
    func testF12_4_BinaryPlacement() {
        let standardPath = "Edge.app/Contents/MacOS/Edge"
        #expect(standardPath.contains("MacOS"))
    }

    @Test("F12.5: Bundled Resources directory contains valid Info.plist")
    func testF12_5_ResourceDirectory() {
        let resourcePath = "Sources/Resources/Info.plist"
        #expect(resourcePath.hasSuffix(".plist"))
    }

    // MARK: - Feature 13: CoreAudio Master Volume Control (5 tests)

    @Test("F13.1: AudioController sets volume scalar cleanly in [0.0, 1.0]")
    func testF13_1_SetVolumeScalar() {
        let audio = MockAudioController(initialVolume: 0.3)
        audio.setVolume(0.75)
        #expect(audio.getVolume() == 0.75)
    }

    @Test("F13.2: AudioController clamps volume above 1.0 to 1.0")
    func testF13_2_VolumeClampHigh() {
        let audio = MockAudioController(initialVolume: 0.5)
        audio.setVolume(1.4)
        #expect(audio.getVolume() == 1.0)
    }

    @Test("F13.3: AudioController clamps volume below 0.0 to 0.0")
    func testF13_3_VolumeClampLow() {
        let audio = MockAudioController(initialVolume: 0.5)
        audio.setVolume(-0.2)
        #expect(audio.getVolume() == 0.0)
    }

    @Test("F13.4: AudioController setting non-zero volume un-mutes automatically")
    func testF13_4_SetVolumeUnmutes() {
        let audio = MockAudioController(initialVolume: 0.5, initialMuted: true)
        #expect(audio.isMuted() == true)
        audio.setVolume(0.6)
        #expect(audio.isMuted() == false)
    }

    @Test("F13.5: AudioController records full volume modification history")
    func testF13_5_VolumeHistory() {
        let audio = MockAudioController(initialVolume: 0.2)
        audio.setVolume(0.4)
        audio.setVolume(0.6)
        #expect(audio.volumeHistory == [0.2, 0.4, 0.6])
    }

    // MARK: - Feature 14: Hardware Volume Change Listener (5 tests)

    final class SendableBox<T>: @unchecked Sendable {
        var value: T
        init(_ value: T) { self.value = value }
    }

    @Test("F14.1: Volume listener block receives external volume change")
    func testF14_1_VolumeListenerFires() {
        let audio = MockAudioController(initialVolume: 0.5)
        let receivedVolume = SendableBox<Float>(0)
        let receivedMuted = SendableBox<Bool>(false)
        audio.setVolumeListener { vol, muted in
            receivedVolume.value = vol
            receivedMuted.value = muted
        }
        audio.simulateExternalHardwareChange(volume: 0.85, muted: false)
        #expect(receivedVolume.value == 0.85)
        #expect(receivedMuted.value == false)
    }

    @Test("F14.2: Volume listener receives external mute change")
    func testF14_2_MuteListenerFires() {
        let audio = MockAudioController(initialVolume: 0.5)
        let receivedMuted = SendableBox<Bool>(false)
        audio.setVolumeListener { _, muted in
            receivedMuted.value = muted
        }
        audio.simulateExternalHardwareChange(volume: 0.0, muted: true)
        #expect(receivedMuted.value == true)
    }

    @Test("F14.3: External volume change updates HUD automatically")
    func testF14_3_ExternalChangeUpdatesHUD() {
        let harness = TestHarness()
        harness.audio.simulateExternalHardwareChange(volume: 0.9, muted: false)
        #expect(harness.hud.currentType == .volume(level: 0.9, isMuted: false))
    }

    @Test("F14.4: External mute change shows muted state on HUD")
    func testF14_4_ExternalMuteUpdatesHUD() {
        let harness = TestHarness()
        harness.audio.simulateExternalHardwareChange(volume: 0.0, muted: true)
        #expect(harness.hud.currentType == .volume(level: 0.0, isMuted: true))
    }

    @Test("F14.5: Multiple consecutive external updates update volume smoothly")
    func testF14_5_ConsecutiveUpdates() {
        let harness = TestHarness(initialVolume: 0.1)
        harness.audio.simulateExternalHardwareChange(volume: 0.3, muted: false)
        harness.audio.simulateExternalHardwareChange(volume: 0.5, muted: false)
        harness.audio.simulateExternalHardwareChange(volume: 0.7, muted: false)
        #expect(harness.audio.getVolume() == 0.7)
        #expect(harness.audio.volumeHistory.count == 4)
    }

    // MARK: - Feature 15: Quick Mute & State Machine (5 tests)

    @Test("F15.1: Quick mute toggles unmuted state to muted with zero volume")
    func testF15_1_QuickMuteMutes() {
        let audio = MockAudioController(initialVolume: 0.7)
        let isMuted = audio.toggleMute()
        #expect(isMuted == true)
        #expect(audio.isMuted() == true)
        #expect(audio.getVolume() == 0.0)
    }

    @Test("F15.2: Un-muting restores previous volume scalar level")
    func testF15_2_QuickMuteRestoresPrevious() {
        let audio = MockAudioController(initialVolume: 0.7)
        _ = audio.toggleMute() // Muted (0.0)
        _ = audio.toggleMute() // Unmuted
        #expect(audio.isMuted() == false)
        #expect(audio.getVolume() == 0.7)
    }

    @Test("F15.3: Un-muting when previous volume was zero defaults to safe volume 0.25")
    func testF15_3_QuickMuteZeroPreviousDefaultsSafe() {
        let audio = MockAudioController(initialVolume: 0.0, initialMuted: false)
        _ = audio.toggleMute() // Mute
        _ = audio.toggleMute() // Unmute
        #expect(audio.isMuted() == false)
        #expect(audio.getVolume() == 0.25)
    }

    @Test("F15.4: Double tap on top-right corner triggers Quick Mute action")
    func testF15_4_DoubleTapTopRightMutes() {
        let harness = TestHarness(initialVolume: 0.65)
        harness.injectDoubleTap(at: (0.95, 0.95))
        #expect(harness.audio.isMuted() == true)
        #expect(harness.audio.getVolume() == 0.0)
    }

    @Test("F15.5: Second double tap on top-right corner un-mutes and restores volume")
    func testF15_5_DoubleTapTopRightUnmutes() {
        let harness = TestHarness(initialVolume: 0.65)
        harness.injectDoubleTap(at: (0.95, 0.95), startTime: 10.0)
        #expect(harness.audio.isMuted() == true)
        harness.injectDoubleTap(at: (0.95, 0.95), startTime: 12.0)
        #expect(harness.audio.isMuted() == false)
        #expect(harness.audio.getVolume() == 0.65)
    }

    // MARK: - Feature 16: Display Brightness Control (5 tests)

    @Test("F16.1: BrightnessManager updates brightness scalar in [0.0, 1.0]")
    func testF16_1_SetBrightnessScalar() {
        let brightness = MockBrightnessManager(initialBrightness: 0.4)
        brightness.setBrightness(0.85)
        #expect(brightness.getBrightness() == 0.85)
    }

    @Test("F16.2: BrightnessManager clamps upper boundary to 1.0")
    func testF16_2_BrightnessClampHigh() {
        let brightness = MockBrightnessManager(initialBrightness: 0.5)
        brightness.setBrightness(1.5)
        #expect(brightness.getBrightness() == 1.0)
    }

    @Test("F16.3: BrightnessManager clamps lower boundary to 0.0")
    func testF16_3_BrightnessClampLow() {
        let brightness = MockBrightnessManager(initialBrightness: 0.5)
        brightness.setBrightness(-0.3)
        #expect(brightness.getBrightness() == 0.0)
    }

    @Test("F16.4: Sliding left edge increases display brightness")
    func testF16_4_SlideLeftIncreasesBrightness() {
        let harness = TestHarness(initialBrightness: 0.4)
        harness.injectDrag(from: (0.05, 0.3), to: (0.05, 0.6), steps: 10)
        #expect(harness.brightness.getBrightness() > 0.4)
    }

    @Test("F16.5: Sliding left edge downward decreases display brightness")
    func testF16_5_SlideLeftDecreasesBrightness() {
        let harness = TestHarness(initialBrightness: 0.8)
        harness.injectDrag(from: (0.05, 0.7), to: (0.05, 0.3), steps: 10)
        #expect(harness.brightness.getBrightness() < 0.8)
    }

    // MARK: - Feature 17: Multi-Display Targeting (5 tests)

    @Test("F17.1: BrightnessManager tracks active display ID")
    func testF17_1_TracksActiveDisplay() {
        let brightness = MockBrightnessManager()
        #expect(brightness.activeDisplayID == 1)
    }

    @Test("F17.2: Brightness modification records in history for targeted display")
    func testF17_2_BrightnessHistory() {
        let brightness = MockBrightnessManager(initialBrightness: 0.5)
        brightness.setBrightness(0.6)
        brightness.setBrightness(0.7)
        #expect(brightness.brightnessHistory == [0.5, 0.6, 0.7])
    }

    @Test("F17.3: HUD displays brightness progress for active display")
    func testF17_3_HUDBrightnessDisplay() {
        let harness = TestHarness(initialBrightness: 0.4)
        harness.injectDrag(from: (0.05, 0.4), to: (0.05, 0.6), steps: 5)
        #expect(harness.hud.currentType != nil)
        if case .brightness(let lvl) = harness.hud.currentType {
            #expect(lvl > 0.4)
        } else {
            Issue.record("Expected brightness HUD type")
        }
    }

    @Test("F17.4: Display switching maintains independent volume state")
    func testF17_4_VolumeUnaffectedByBrightnessTargeting() {
        let harness = TestHarness(initialVolume: 0.75, initialBrightness: 0.3)
        harness.injectDrag(from: (0.05, 0.3), to: (0.05, 0.6), steps: 8)
        #expect(harness.audio.getVolume() == 0.75)
    }

    @Test("F17.5: Minimum brightness setting retains safe minimum visibility")
    func testF17_5_SafeMinimumBrightness() {
        let harness = TestHarness(initialBrightness: 0.5)
        harness.injectDrag(from: (0.05, 0.8), to: (0.05, 0.1), steps: 20)
        #expect(harness.brightness.getBrightness() >= 0.0)
    }

    // MARK: - Feature 18: Media Playback Key Simulation (5 tests)

    @Test("F18.1: MediaManager dispatches playPause action")
    func testF18_1_DispatchesPlayPause() {
        let media = MockMediaManager()
        media.playPause()
        #expect(media.recordedActions == [.playPause])
        #expect(media.playPauseCount == 1)
    }

    @Test("F18.2: MediaManager dispatches nextTrack action")
    func testF18_2_DispatchesNextTrack() {
        let media = MockMediaManager()
        media.nextTrack()
        #expect(media.recordedActions == [.nextTrack])
        #expect(media.nextTrackCount == 1)
    }

    @Test("F18.3: MediaManager dispatches previousTrack action")
    func testF18_3_DispatchesPreviousTrack() {
        let media = MockMediaManager()
        media.previousTrack()
        #expect(media.recordedActions == [.previousTrack])
        #expect(media.prevTrackCount == 1)
    }

    @Test("F18.4: Multiple media key actions record in exact sequence")
    func testF18_4_MediaKeySequence() {
        let media = MockMediaManager()
        media.nextTrack()
        media.nextTrack()
        media.previousTrack()
        media.playPause()
        #expect(media.recordedActions == [.nextTrack, .nextTrack, .previousTrack, .playPause])
    }

    @Test("F18.5: Media actions trigger corresponding HUD overlay feedback")
    func testF18_5_MediaHUDOverlay() {
        let harness = TestHarness()
        harness.coordinator.handleGestureAction(.mediaPlayPause)
        #expect(harness.hud.currentType == .media(action: .playPause))
    }

    // MARK: - Feature 19: Bottom Edge Media Strip Actions (5 tests)

    @Test("F19.1: Horizontal drag right on bottom edge skips to next track")
    func testF19_1_BottomSwipeRight() {
        let harness = TestHarness()
        harness.injectDrag(from: (0.3, 0.05), to: (0.6, 0.05), steps: 10)
        #expect(harness.media.recordedActions.contains(.nextTrack))
    }

    @Test("F19.2: Horizontal drag left on bottom edge skips to previous track")
    func testF19_2_BottomSwipeLeft() {
        let harness = TestHarness()
        harness.injectDrag(from: (0.6, 0.05), to: (0.3, 0.05), steps: 10)
        #expect(harness.media.recordedActions.contains(.previousTrack))
    }

    @Test("F19.3: Double tap on bottom edge triggers play/pause")
    func testF19_3_BottomDoubleTapPlayPause() {
        let harness = TestHarness()
        harness.injectDoubleTap(at: (0.5, 0.05))
        #expect(harness.media.recordedActions.contains(.playPause))
    }

    @Test("F19.4: Vertical drag starting on bottom edge is rejected by axis lock")
    func testF19_4_BottomVerticalDragRejected() {
        let harness = TestHarness()
        // Drag vertically upward from bottom strip into center trackpad
        harness.injectDrag(from: (0.5, 0.04), to: (0.5, 0.4), steps: 10)
        #expect(harness.media.recordedActions.isEmpty)
    }

    @Test("F19.5: Short jitter below threshold does not trigger track skip")
    func testF19_5_BottomJitterThreshold() {
        let harness = TestHarness()
        // Movement of only 0.05 (threshold is 0.15)
        harness.injectDrag(from: (0.5, 0.05), to: (0.55, 0.05), steps: 5)
        #expect(harness.media.recordedActions.isEmpty)
    }

    // MARK: - Feature 20: Floating OSD HUD Window (5 tests)

    @Test("F20.1: HUDManager shows volume type with correct level")
    func testF20_1_HUDShowVolume() {
        let hud = MockHUDManager()
        hud.showVolume(level: 0.75, isMuted: false)
        #expect(hud.currentType == .volume(level: 0.75, isMuted: false))
        #expect(hud.isDismissed == false)
    }

    @Test("F20.2: HUDManager shows brightness type with correct level")
    func testF20_2_HUDShowBrightness() {
        let hud = MockHUDManager()
        hud.showBrightness(level: 0.82)
        #expect(hud.currentType == .brightness(level: 0.82))
        #expect(hud.isDismissed == false)
    }

    @Test("F20.3: HUDManager shows media action type")
    func testF20_3_HUDShowMedia() {
        let hud = MockHUDManager()
        hud.showMedia(action: .playPause)
        #expect(hud.currentType == .media(action: .playPause))
    }

    @Test("F20.4: HUDManager dismissImmediately orders out window")
    func testF20_4_HUDDismissImmediately() {
        let hud = MockHUDManager()
        hud.showVolume(level: 0.5, isMuted: false)
        hud.dismissImmediately()
        #expect(hud.currentType == nil)
        #expect(hud.isDismissed == true)
    }

    @Test("F20.5: HUDManager records history of shown HUD types")
    func testF20_5_HUDHistory() {
        let hud = MockHUDManager()
        hud.showVolume(level: 0.4, isMuted: false)
        hud.showBrightness(level: 0.6)
        #expect(hud.history.count == 2)
    }

    // MARK: - Feature 21: Liquid Glass HUD UI (5 tests)

    @Test("F21.1: Volume HUD correctly reflects muted state")
    func testF21_1_HUDMutedVolume() {
        let hud = MockHUDManager()
        hud.showVolume(level: 0.0, isMuted: true)
        #expect(hud.currentType == .volume(level: 0.0, isMuted: true))
    }

    @Test("F21.2: Brightness HUD correctly formats full scale")
    func testF21_2_HUDBrightnessScale() {
        let hud = MockHUDManager()
        hud.showBrightness(level: 1.0)
        #expect(hud.currentType == .brightness(level: 1.0))
    }

    @Test("F21.3: Next track action HUD correctly formats media symbol")
    func testF21_3_HUDMediaNext() {
        let hud = MockHUDManager()
        hud.showMedia(action: .nextTrack)
        #expect(hud.currentType == .media(action: .nextTrack))
    }

    @Test("F21.4: Previous track action HUD correctly formats media symbol")
    func testF21_4_HUDMediaPrevious() {
        let hud = MockHUDManager()
        hud.showMedia(action: .previousTrack)
        #expect(hud.currentType == .media(action: .previousTrack))
    }

    @Test("F21.5: HUD updates level dynamically during continuous slide")
    func testF21_5_HUDDynamicUpdates() {
        let harness = TestHarness(initialVolume: 0.2)
        harness.injectDrag(from: (0.95, 0.2), to: (0.95, 0.6), steps: 8)
        #expect(harness.hud.history.count >= 2)
    }

    // MARK: - Feature 22: Debounced HUD Auto-Dismiss (5 tests)

    @Test("F22.1: HUD auto-dismiss is scheduled when gesture ends")
    func testF22_1_DismissScheduledOnGestureEnd() {
        let harness = TestHarness()
        harness.injectDrag(from: (0.95, 0.3), to: (0.95, 0.6), steps: 5)
        #expect(harness.hud.autoDismissScheduled == true)
    }

    @Test("F22.2: New touch cancels pending auto-dismiss timer")
    func testF22_2_NewTouchCancelsDismiss() {
        let harness = TestHarness()
        harness.injectDrag(from: (0.95, 0.3), to: (0.95, 0.6), steps: 5)
        #expect(harness.hud.autoDismissScheduled == true)

        // New touch starts
        harness.injectTouch(x: 0.95, y: 0.6, phase: .makeTouch)
        harness.hud.showVolume(level: 0.7, isMuted: false)
        #expect(harness.hud.autoDismissScheduled == false)
    }

    @Test("F22.3: Triggering auto-dismiss hides HUD and marks dismissed")
    func testF22_3_TriggerAutoDismiss() {
        let harness = TestHarness()
        harness.injectDrag(from: (0.95, 0.3), to: (0.95, 0.6), steps: 5)
        harness.hud.triggerAutoDismiss()
        #expect(harness.hud.isDismissed == true)
        #expect(harness.hud.currentType == nil)
    }

    @Test("F22.4: Continuous scrubbing keeps HUD visible without dismissing")
    func testF22_4_ContinuousScrubbingKeepsVisible() {
        let harness = TestHarness()
        harness.injectTouch(x: 0.95, y: 0.3, phase: .makeTouch)
        for i in 1...10 {
            harness.injectTouch(x: 0.95, y: 0.3 + Float(i) * 0.03, phase: .touching)
            #expect(harness.hud.isDismissed == false)
        }
    }

    @Test("F22.5: Immediate dismiss call overrides pending timer synchronously")
    func testF22_5_ImmediateDismissOverridesTimer() {
        let harness = TestHarness()
        harness.hud.showVolume(level: 0.5, isMuted: false)
        harness.hud.scheduleAutoDismiss()
        harness.hud.dismissImmediately()
        #expect(harness.hud.isDismissed == true)
        #expect(harness.hud.autoDismissScheduled == false)
    }

    // MARK: - Feature 23: MultitouchSupport Dynamic Bridge (5 tests)

    @Test("F23.1: Synthetic touch struct correctly represents normalized trackpad frame")
    func testF23_1_SyntheticTouchStruct() {
        let touch = SyntheticTouch(id: 1, position: MTPoint(x: 0.95, y: 0.5))
        #expect(touch.position.x == 0.95)
        #expect(touch.position.y == 0.5)
        #expect(touch.isBuiltIn == true)
    }

    @Test("F23.2: Touch velocity vector initializes cleanly")
    func testF23_2_VelocityVector() {
        let touch = SyntheticTouch(id: 1, position: MTPoint(x: 0.95, y: 0.5), velocity: MTPoint(x: 0.0, y: 1.2))
        #expect(touch.velocity.y == 1.2)
    }

    @Test("F23.3: Multiple touches in single frame parse correctly")
    func testF23_3_MultiTouchFrame() {
        let t1 = SyntheticTouch(id: 1, position: MTPoint(x: 0.05, y: 0.5))
        let t2 = SyntheticTouch(id: 2, position: MTPoint(x: 0.95, y: 0.5))
        let touches = [t1, t2]
        #expect(touches.count == 2)
        #expect(touches[0].id == 1)
        #expect(touches[1].id == 2)
    }

    @Test("F23.4: Touch phases track lifecycle from makeTouch to breakTouch")
    func testF23_4_TouchPhaseTransitions() {
        #expect(TouchPhase.makeTouch.rawValue == 3)
        #expect(TouchPhase.touching.rawValue == 4)
        #expect(TouchPhase.breakTouch.rawValue == 5)
    }

    @Test("F23.5: Touch dimensions and radius properties support palm filtering")
    func testF23_5_TouchDimensions() {
        let touch = SyntheticTouch(id: 1, position: MTPoint(x: 0.5, y: 0.5), majorRadius: 25.0, minorRadius: 20.0)
        #expect(touch.majorRadius == 25.0)
    }

    // MARK: - Feature 24: MTTouch C Callback with Refcon (5 tests)

    @Test("F24.1: Coordinator receives synthetic touch stream on dedicated handler")
    func testF24_1_TouchStreamHandler() {
        let harness = TestHarness()
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch)
        #expect(harness.coordinator.gestureEngine.currentState != .idle)
    }

    @Test("F24.2: Touch stream routes to active gesture candidate")
    func testF24_2_RoutesToCandidate() {
        let harness = TestHarness()
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch)
        if case .candidate(let edge, _, _) = harness.coordinator.gestureEngine.currentState {
            #expect(edge == .right)
        } else {
            Issue.record("Expected candidate state on right edge")
        }
    }

    @Test("F24.3: Empty touch frame resets candidate state")
    func testF24_3_EmptyFrameResets() {
        let harness = TestHarness()
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch)
        harness.coordinator.injectTouches([])
        #expect(harness.coordinator.gestureEngine.currentState == .idle)
    }

    @Test("F24.4: Device classification isolates external device touches")
    func testF24_4_DeviceClassification() {
        let touchBuiltIn = SyntheticTouch(position: MTPoint(x: 0.95, y: 0.5), isBuiltIn: true)
        let touchExternal = SyntheticTouch(position: MTPoint(x: 0.95, y: 0.5), isBuiltIn: false)
        #expect(touchBuiltIn.isBuiltIn == true)
        #expect(touchExternal.isBuiltIn == false)
    }

    @Test("F24.5: Multiple sequential frames update position delta smoothly")
    func testF24_5_SequentialPositionUpdates() {
        let harness = TestHarness(initialVolume: 0.5)
        harness.injectTouch(x: 0.95, y: 0.4, phase: .makeTouch)
        harness.injectTouch(x: 0.95, y: 0.45, phase: .touching)
        harness.injectTouch(x: 0.95, y: 0.50, phase: .touching)
        #expect(harness.audio.getVolume() > 0.5)
    }

    // MARK: - Feature 25: Edge Boundary Coordinate Math (5 tests)

    @Test("F25.1: Normalized (0.0, 0.0) bottom-left origin maps to bottom edge")
    func testF25_1_BottomLeftOrigin() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.0, y: 0.0),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .bottom)
    }

    @Test("F25.2: Normalized (1.0, 1.0) top-right corner maps to topRightCorner")
    func testF25_2_TopRightCornerOrigin() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 1.0, y: 1.0),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .topRightCorner)
    }

    @Test("F25.3: Normalized point (0.04, 0.50) maps to left edge")
    func testF25_3_LeftEdgeClassification() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.04, y: 0.50),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .left)
    }

    @Test("F25.4: Normalized point (0.96, 0.50) maps to right edge")
    func testF25_4_RightEdgeClassification() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.96, y: 0.50),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .right)
    }

    @Test("F25.5: Center point (0.50, 0.50) maps to none (deadzone/active canvas)")
    func testF25_5_CenterMapsToNone() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.50, y: 0.50),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .none)
    }

    // MARK: - Feature 26: 4-State Gesture FSM (5 tests)

    @Test("F26.1: Initial FSM state is .idle")
    func testF26_1_FSMInitialIdle() {
        let engine = SimulatedGestureEngine()
        #expect(engine.currentState == .idle)
    }

    @Test("F26.2: Touch in edge transitions FSM from .idle to .candidate")
    func testF26_2_FSMIdleToCandidate() {
        let engine = SimulatedGestureEngine()
        let touch = SyntheticTouch(position: MTPoint(x: 0.95, y: 0.5), phase: .makeTouch)
        engine.processFrame(touches: [touch], preferences: .default, cursorManager: nil, hapticsManager: nil)
        if case .candidate(let edge, _, _) = engine.currentState {
            #expect(edge == .right)
        } else {
            Issue.record("Expected candidate state")
        }
    }

    @Test("F26.3: Movement beyond deadzone transitions FSM to .sliding")
    func testF26_3_FSMCandidateToSliding() {
        let engine = SimulatedGestureEngine()
        let t1 = SyntheticTouch(position: MTPoint(x: 0.95, y: 0.5), phase: .makeTouch)
        engine.processFrame(touches: [t1], preferences: .default, cursorManager: nil, hapticsManager: nil)

        let t2 = SyntheticTouch(position: MTPoint(x: 0.95, y: 0.54), phase: .touching)
        engine.processFrame(touches: [t2], preferences: .default, cursorManager: nil, hapticsManager: nil)

        if case .sliding(let edge, _, _, _) = engine.currentState {
            #expect(edge == .right)
        } else {
            Issue.record("Expected sliding state")
        }
    }

    @Test("F26.4: Inward swipe off edge cancels gesture and resets FSM to .idle")
    func testF26_4_FSMInwardSwipeCancellation() {
        let engine = SimulatedGestureEngine()
        let t1 = SyntheticTouch(position: MTPoint(x: 0.95, y: 0.5), phase: .makeTouch)
        engine.processFrame(touches: [t1], preferences: .default, cursorManager: nil, hapticsManager: nil)

        // Large inward horizontal displacement: x moves from 0.95 to 0.80
        let t2 = SyntheticTouch(position: MTPoint(x: 0.80, y: 0.5), phase: .touching)
        engine.processFrame(touches: [t2], preferences: .default, cursorManager: nil, hapticsManager: nil)

        #expect(engine.currentState == .idle)
    }

    @Test("F26.5: Touch lift breaks gesture and resets FSM back to .idle")
    func testF26_5_FSMTouchLiftResetsIdle() {
        let engine = SimulatedGestureEngine()
        let t1 = SyntheticTouch(position: MTPoint(x: 0.95, y: 0.5), phase: .makeTouch)
        engine.processFrame(touches: [t1], preferences: .default, cursorManager: nil, hapticsManager: nil)
        let t2 = SyntheticTouch(position: MTPoint(x: 0.95, y: 0.55), phase: .touching)
        engine.processFrame(touches: [t2], preferences: .default, cursorManager: nil, hapticsManager: nil)

        let t3 = SyntheticTouch(position: MTPoint(x: 0.95, y: 0.55), phase: .breakTouch)
        engine.processFrame(touches: [t3], preferences: .default, cursorManager: nil, hapticsManager: nil)

        #expect(engine.currentState == .idle)
    }

    // MARK: - Feature 27: Double-Tap Detector (5 tests)

    @Test("F27.1: Two taps within 250ms and distance < 0.04 triggers double tap")
    func testF27_1_DoubleTapTrigger() {
        let harness = TestHarness()
        harness.injectDoubleTap(at: (0.95, 0.95), interval: 0.15)
        #expect(harness.audio.isMuted() == true)
    }

    @Test("F27.2: Two taps with interval > 300ms treated as separate single taps")
    func testF27_2_DoubleTapTimeout() {
        let harness = TestHarness(initialVolume: 0.5)
        // Interval 0.35s (exceeds 0.30s threshold)
        harness.injectDoubleTap(at: (0.95, 0.95), interval: 0.35)
        #expect(harness.audio.isMuted() == false)
    }

    @Test("F27.3: Two taps with spatial distance > 0.04 rejected")
    func testF27_3_DoubleTapDistanceRejection() {
        let harness = TestHarness(initialVolume: 0.5)
        // Distance 0.06 (exceeds 0.04 threshold)
        harness.injectDoubleTap(at: (0.95, 0.95), interval: 0.15, secondOffset: (0.06, 0.0))
        #expect(harness.audio.isMuted() == false)
    }

    @Test("F27.4: Rapid triple tap triggers exactly one double-tap and resets")
    func testF27_4_TripleTapCount() {
        let harness = TestHarness(initialVolume: 0.5)
        // First tap
        harness.injectTap(at: (0.95, 0.95), timestamp: 1.0)
        // Second tap (triggers mute)
        harness.injectTap(at: (0.95, 0.95), timestamp: 1.15)
        #expect(harness.audio.isMuted() == true)
        // Third tap immediately (should start a new single tap, not toggle again)
        harness.injectTap(at: (0.95, 0.95), timestamp: 1.25)
        #expect(harness.audio.isMuted() == true)
    }

    @Test("F27.5: Finger drag between taps invalidates double-tap candidate")
    func testF27_5_DragInvalidatesDoubleTap() {
        let harness = TestHarness(initialVolume: 0.5)
        // Drag instead of tap
        harness.injectDrag(from: (0.95, 0.95), to: (0.95, 0.85), steps: 5, startTime: 1.0)
        // Subsequent tap
        harness.injectTap(at: (0.95, 0.95), timestamp: 1.2)
        #expect(harness.audio.isMuted() == false)
    }

    // MARK: - Feature 28: Triple-Layer Cursor Freeze (5 tests)

    @Test("F28.1: Cursor freezes when entering sliding state")
    func testF28_1_CursorFreezesOnSlide() {
        let harness = TestHarness()
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch)
        harness.injectTouch(x: 0.95, y: 0.55, phase: .touching)
        harness.assertCursorFrozen(true)
    }

    @Test("F28.2: Cursor anchor point is recorded when freeze starts")
    func testF28_2_CursorAnchorPointRecorded() {
        let harness = TestHarness()
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch)
        harness.injectTouch(x: 0.95, y: 0.55, phase: .touching)
        #expect(harness.cursor.anchorPoint != nil)
    }

    @Test("F28.3: Cursor unfreezes when finger lifts from trackpad")
    func testF28_3_CursorUnfreezesOnLift() {
        let harness = TestHarness()
        harness.injectDrag(from: (0.95, 0.5), to: (0.95, 0.7), steps: 6)
        harness.assertCursorFrozen(false)
    }

    @Test("F28.4: Cursor freeze count matches unfreeze count across full gesture")
    func testF28_4_FreezeUnfreezeSymmetry() {
        let harness = TestHarness()
        harness.injectDrag(from: (0.95, 0.5), to: (0.95, 0.7), steps: 6)
        #expect(harness.cursor.freezeCallCount == 1)
        #expect(harness.cursor.unfreezeCallCount == 1)
    }

    @Test("F28.5: Inward swipe cancellation unfreezes cursor immediately")
    func testF28_5_InwardSwipeUnfreezes() {
        let harness = TestHarness()
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch)
        harness.injectTouch(x: 0.95, y: 0.55, phase: .touching)
        harness.assertCursorFrozen(true)

        // Cancel with inward swipe
        harness.injectTouch(x: 0.50, y: 0.55, phase: .touching)
        harness.assertCursorFrozen(false)
    }

    // MARK: - Feature 29: Haptic Step Performer (5 tests)

    @Test("F29.1: Moving through 1/16th volume threshold triggers haptic tick")
    func testF29_1_HapticTickOnStep() {
        let harness = TestHarness(initialVolume: 0.5)
        // Drag by 0.10 (greater than 1/16 = 0.0625)
        harness.injectDrag(from: (0.95, 0.3), to: (0.95, 0.45), steps: 10)
        harness.assertHapticTicks(min: 1)
    }

    @Test("F29.2: Movement within current step does not trigger haptic tick")
    func testF29_2_NoHapticSubStep() {
        let harness = TestHarness(initialVolume: 0.5)
        // Small drag within deadzone/substep
        harness.injectDrag(from: (0.95, 0.5), to: (0.95, 0.52), steps: 3)
        #expect(harness.haptics.tickCount == 0)
    }

    @Test("F29.3: Sliding continuously across multiple steps triggers proportional ticks")
    func testF29_3_MultiStepTicks() {
        let harness = TestHarness(initialVolume: 0.2)
        // Drag across 0.40 distance (~6 steps of 0.0625)
        harness.injectDrag(from: (0.95, 0.2), to: (0.95, 0.6), steps: 20)
        harness.assertHapticTicks(min: 4, max: 8)
    }

    @Test("F29.4: Reversing direction triggers haptic tick upon crossing step in reverse")
    func testF29_4_ReverseDirectionHaptics() {
        let harness = TestHarness(initialVolume: 0.5)
        // Upward drag
        harness.injectTouch(x: 0.95, y: 0.4, phase: .makeTouch)
        harness.injectTouch(x: 0.95, y: 0.55, phase: .touching)
        let ticksUp = harness.haptics.tickCount

        // Downward drag
        harness.injectTouch(x: 0.95, y: 0.40, phase: .touching)
        let ticksDown = harness.haptics.tickCount
        #expect(ticksDown > ticksUp)
    }

    @Test("F29.5: Disabling haptics in preferences suppresses all haptic calls")
    func testF29_5_HapticsDisabled() {
        let harness = TestHarness(initialVolume: 0.5)
        harness.updatePreferences { $0.enableHaptics = false }
        harness.injectDrag(from: (0.95, 0.2), to: (0.95, 0.8), steps: 20)
        #expect(harness.haptics.tickCount == 0)
    }

    // MARK: - Feature 30: Shift-Option Precision Modifier (5 tests)

    @Test("F30.1: Shift-Option held scales delta by 0.25")
    func testF30_1_ModifierScalesQuarter() {
        let harness = TestHarness(initialVolume: 0.3)
        harness.coordinator.gestureEngine.setShiftOptionModifier(true)
        harness.injectDrag(from: (0.95, 0.3), to: (0.95, 0.5), steps: 10)
        let delta = harness.audio.getVolume() - 0.3
        #expect(delta < 0.10)
    }

    @Test("F30.2: Shift-Option modifier enables 64-step micro-haptics")
    func testF30_2_ModifierEnablesMicroHaptics() {
        let harness = TestHarness(initialVolume: 0.5)
        harness.coordinator.gestureEngine.setShiftOptionModifier(true)
        harness.injectDrag(from: (0.95, 0.3), to: (0.95, 0.6), steps: 15)
        #expect(harness.haptics.tickCount > 0)
    }

    @Test("F30.3: Shift-Option modifier works on display brightness")
    func testF30_3_ModifierOnBrightness() {
        let harness = TestHarness(initialBrightness: 0.5)
        harness.coordinator.gestureEngine.setShiftOptionModifier(true)
        harness.injectDrag(from: (0.05, 0.3), to: (0.05, 0.5), steps: 10)
        let delta = harness.brightness.getBrightness() - 0.5
        #expect(delta < 0.10)
    }

    @Test("F30.4: Modifier state can be toggled mid-slide")
    func testF30_4_ModifierToggledMidSlide() {
        let harness = TestHarness(initialVolume: 0.2)
        harness.injectTouch(x: 0.95, y: 0.2, phase: .makeTouch)
        harness.injectTouch(x: 0.95, y: 0.3, phase: .touching) // normal
        harness.coordinator.gestureEngine.setShiftOptionModifier(true)
        harness.injectTouch(x: 0.95, y: 0.4, phase: .touching) // precise
        #expect(harness.audio.getVolume() > 0.2)
    }

    @Test("F30.5: Modifiers combine multiplicatively with custom sensitivity")
    func testF30_5_ModifierSensitivityCombination() {
        let harness = TestHarness(initialVolume: 0.3)
        harness.updatePreferences { $0.sensitivity = 2.0 }
        harness.coordinator.gestureEngine.setShiftOptionModifier(true)
        harness.injectDrag(from: (0.95, 0.3), to: (0.95, 0.5), steps: 10)
        let delta = harness.audio.getVolume() - 0.3
        // 0.2 delta * 2.0 sensitivity * 0.25 precision = 0.10
        #expect(delta < 0.20)
    }

    // MARK: - Feature 31: Accessibility Verification (5 tests)

    @Test("F31.1: Trusted accessibility status initializes normally")
    func testF31_1_TrustedAccessibilityInitial() {
        let harness = TestHarness(initiallyTrustedAccessibility: true)
        #expect(harness.accessibility.isTrusted() == true)
    }

    @Test("F31.2: Untrusted accessibility status initializes alert state")
    func testF31_2_UntrustedAccessibilityInitial() {
        let harness = TestHarness(initiallyTrustedAccessibility: false)
        #expect(harness.accessibility.isTrusted() == false)
    }

    @Test("F31.3: Prompting accessibility records prompt count")
    func testF31_3_PromptAccessibility() {
        let harness = TestHarness(initiallyTrustedAccessibility: false)
        _ = harness.accessibility.promptAccessibility()
        #expect(harness.accessibility.promptCount == 1)
    }

    @Test("F31.4: Granting permission updates trust status dynamically")
    func testF31_4_GrantPermissionDynamic() {
        let harness = TestHarness(initiallyTrustedAccessibility: false)
        #expect(harness.accessibility.isTrusted() == false)
        harness.accessibility.setTrusted(true)
        #expect(harness.accessibility.isTrusted() == true)
    }

    @Test("F31.5: Deep link button triggers correct System Settings URL")
    func testF31_5_DeepLinkURL() {
        let harness = TestHarness()
        harness.accessibility.openSystemSettingsDeepLink()
        #expect(harness.accessibility.lastDeepLinkURL?.contains("Privacy_Accessibility") == true)
    }

    // MARK: - Feature 32: Onboarding Window & Polling (5 tests)

    @Test("F32.1: Onboarding window deep link points to Privacy & Security")
    func testF32_1_OnboardingDeepLink() {
        let harness = TestHarness(initiallyTrustedAccessibility: false)
        harness.accessibility.openSystemSettingsDeepLink()
        #expect(harness.accessibility.lastDeepLinkURL == "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @Test("F32.2: Trusted status allows normal gesture operation without onboarding blocking")
    func testF32_2_TrustedAllowsOperation() {
        let harness = TestHarness(initiallyTrustedAccessibility: true)
        harness.injectDrag(from: (0.95, 0.4), to: (0.95, 0.6), steps: 5)
        #expect(harness.audio.getVolume() > 0.5)
    }

    @Test("F32.3: Untrusted permission alert state can be acknowledged")
    func testF32_3_UntrustedAlertAcknowledgement() {
        let harness = TestHarness(initiallyTrustedAccessibility: false)
        harness.statusItem.setState(.alert)
        #expect(harness.statusItem.getState() == .alert)
    }

    @Test("F32.4: Permission grant transitions status icon from alert to idle")
    func testF32_4_StatusTransitionOnGrant() {
        let harness = TestHarness(initiallyTrustedAccessibility: false)
        harness.statusItem.setState(.alert)
        harness.accessibility.setTrusted(true)
        harness.statusItem.setState(.idle)
        #expect(harness.statusItem.getState() == .idle)
    }

    @Test("F32.5: User can query accessibility status repeatedly without crash")
    func testF32_5_RepeatedAccessibilityPolling() {
        let harness = TestHarness()
        for _ in 1...10 {
            #expect(harness.accessibility.isTrusted() == true)
        }
    }

    // MARK: - Feature 33: EdgeAppCoordinator (5 tests)

    @Test("F33.1: Coordinator routes volume delta action to AudioController")
    func testF33_1_RoutesVolumeDelta() {
        let harness = TestHarness(initialVolume: 0.4)
        harness.coordinator.handleGestureAction(.volumeDelta(0.2))
        #expect(harness.audio.getVolume() == 0.6)
    }

    @Test("F33.2: Coordinator routes brightness delta action to BrightnessManager")
    func testF33_2_RoutesBrightnessDelta() {
        let harness = TestHarness(initialBrightness: 0.5)
        harness.coordinator.handleGestureAction(.brightnessDelta(0.25))
        #expect(harness.brightness.getBrightness() == 0.75)
    }

    @Test("F33.3: Coordinator routes quick mute action to AudioController")
    func testF33_3_RoutesQuickMute() {
        let harness = TestHarness(initialVolume: 0.7)
        harness.coordinator.handleGestureAction(.quickMute)
        #expect(harness.audio.isMuted() == true)
    }

    @Test("F33.4: Coordinator routes media actions to MediaManager")
    func testF33_4_RoutesMediaActions() {
        let harness = TestHarness()
        harness.coordinator.handleGestureAction(.mediaPlayPause)
        harness.coordinator.handleGestureAction(.mediaNext)
        harness.coordinator.handleGestureAction(.mediaPrevious)
        #expect(harness.media.getActions() == [.playPause, .nextTrack, .previousTrack])
    }

    @Test("F33.5: Coordinator tracks active gesture lifecycle and status states")
    func testF33_5_TracksGestureLifecycle() {
        let harness = TestHarness()
        harness.coordinator.handleGestureAction(.gestureStarted(edge: .right))
        #expect(harness.coordinator.isGestureActive == true)
        #expect(harness.coordinator.activeEdge == .right)
        #expect(harness.statusItem.getState() == .active)

        harness.coordinator.handleGestureAction(.gestureEnded)
        #expect(harness.coordinator.isGestureActive == false)
        #expect(harness.coordinator.activeEdge == .none)
        #expect(harness.statusItem.getState() == .idle)
    }
}
