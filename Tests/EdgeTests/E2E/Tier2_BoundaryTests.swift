//
//  Tier2_BoundaryTests.swift
//  EdgeTests
//
//  Tier 2: Boundary, Corner & Extreme Value Tests.
//  Validates edge margin tolerances, deadzone cutoffs, scalar saturation,
//  double-tap timing limits, coordinate extremes, and palm rejection.
//

import Foundation
import Testing

@Suite("Tier 2: Boundary & Corner Tests")
struct Tier2_BoundaryTests {

    // MARK: - Edge Margin Exact Thresholds

    @Test("T2.01: Left edge threshold accepts at exact edgeWidth boundary")
    func testT2_01_LeftEdgeExactBoundary() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.08, y: 0.5),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .left)
    }

    @Test("T2.02: Left edge threshold rejects 0.001 beyond edgeWidth boundary")
    func testT2_02_LeftEdgeOutsideBoundary() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.081, y: 0.5),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .none)
    }

    @Test("T2.03: Left edge threshold accepts 0.001 within edgeWidth boundary")
    func testT2_03_LeftEdgeInsideBoundary() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.079, y: 0.5),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .left)
    }

    @Test("T2.04: Right edge threshold accepts at exact (1.0 - edgeWidth) boundary")
    func testT2_04_RightEdgeExactBoundary() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.92, y: 0.5),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .right)
    }

    @Test("T2.05: Right edge threshold rejects 0.001 outside right margin")
    func testT2_05_RightEdgeOutsideBoundary() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.919, y: 0.5),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .none)
    }

    @Test("T2.06: Right edge threshold accepts 0.001 inside right margin")
    func testT2_06_RightEdgeInsideBoundary() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.921, y: 0.5),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .right)
    }

    @Test("T2.07: Bottom edge threshold accepts at exact bottomMargin boundary")
    func testT2_07_BottomEdgeExactBoundary() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.5, y: 0.09),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .bottom)
    }

    @Test("T2.08: Bottom edge threshold rejects 0.001 above bottomMargin boundary")
    func testT2_08_BottomEdgeAboveBoundary() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.5, y: 0.091),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .none)
    }

    @Test("T2.09: Bottom edge threshold accepts 0.001 below bottomMargin boundary")
    func testT2_09_BottomEdgeBelowBoundary() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.5, y: 0.089),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .bottom)
    }

    // MARK: - Corner Thresholds & Precedence

    @Test("T2.10: Top-right corner accepts at exact (1.0 - cornerMargin) boundary")
    func testT2_10_CornerExactBoundary() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.84, y: 0.84),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .topRightCorner)
    }

    @Test("T2.11: Top-right corner rejects when X is 0.001 below corner threshold")
    func testT2_11_CornerBelowXBoundary() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.839, y: 0.85),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge != .topRightCorner)
    }

    @Test("T2.12: Top-right corner rejects when Y is 0.001 below corner threshold")
    func testT2_12_CornerBelowYBoundary() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.85, y: 0.839),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge != .topRightCorner)
    }

    @Test("T2.13: Corner touch at (1.0, 1.0) extreme is classified as topRightCorner")
    func testT2_13_ExtremeCornerOrigin() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 1.0, y: 1.0),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .topRightCorner)
    }

    @Test("T2.14: Bottom-left corner touch at (0.0, 0.0) is classified as bottom edge")
    func testT2_14_BottomLeftCornerOrigin() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.0, y: 0.0),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .bottom)
    }

    // MARK: - Deadzone Bounds

    @Test("T2.15: Movement of 0.019 (below 0.02 deadzone) remains in candidate state")
    func testT2_15_SubDeadzoneMovement() {
        let harness = TestHarness()
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch)
        harness.injectTouch(x: 0.95, y: 0.519, phase: .touching)
        harness.assertCursorFrozen(false)
        #expect(harness.audio.setVolumeCallCount == 0)
    }

    @Test("T2.16: Movement of 0.021 (above 0.02 deadzone) breaks into sliding state")
    func testT2_16_SuperDeadzoneMovement() {
        let harness = TestHarness()
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch)
        harness.injectTouch(x: 0.95, y: 0.521, phase: .touching)
        harness.assertCursorFrozen(true)
        #expect(harness.audio.setVolumeCallCount > 0)
    }

    @Test("T2.17: Horizontal jitter within deadzone on vertical slider does not cancel candidate")
    func testT2_17_HorizontalJitterSubDeadzone() {
        let harness = TestHarness()
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch)
        harness.injectTouch(x: 0.94, y: 0.5, phase: .touching)
        #expect(harness.coordinator.gestureEngine.currentState != .idle)
    }

    @Test("T2.18: Inward swipe of 0.05 cancels candidate state cleanly")
    func testT2_18_InwardSwipeCancels() {
        let harness = TestHarness()
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch)
        harness.injectTouch(x: 0.88, y: 0.5, phase: .touching)
        #expect(harness.coordinator.gestureEngine.currentState == .idle)
    }

    // MARK: - Scalar Saturation & Clamping

    @Test("T2.19: Volume upper saturation clamps at exactly 1.0 without overflow")
    func testT2_19_VolumeSaturationHigh() {
        let harness = TestHarness(initialVolume: 0.95)
        harness.injectDrag(from: (0.95, 0.5), to: (0.95, 0.9), steps: 10)
        harness.assertVolume(1.0, accuracy: 0.0001)
    }

    @Test("T2.20: Volume lower saturation clamps at exactly 0.0 without underflow")
    func testT2_20_VolumeSaturationLow() {
        let harness = TestHarness(initialVolume: 0.05)
        harness.injectDrag(from: (0.95, 0.5), to: (0.95, 0.1), steps: 10)
        harness.assertVolume(0.0, accuracy: 0.0001)
    }

    @Test("T2.21: Brightness upper saturation clamps at exactly 1.0 without overflow")
    func testT2_21_BrightnessSaturationHigh() {
        let harness = TestHarness(initialBrightness: 0.95)
        harness.injectDrag(from: (0.05, 0.5), to: (0.05, 0.9), steps: 10)
        harness.assertBrightness(1.0, accuracy: 0.0001)
    }

    @Test("T2.22: Brightness lower saturation clamps at exactly 0.0 without underflow")
    func testT2_22_BrightnessSaturationLow() {
        let harness = TestHarness(initialBrightness: 0.05)
        harness.injectDrag(from: (0.05, 0.5), to: (0.05, 0.1), steps: 10)
        harness.assertBrightness(0.0, accuracy: 0.0001)
    }

    // MARK: - Active Area Boundary Cutoffs

    @Test("T2.23: ActiveArea .bottomHalf accepts touch at exact y=0.50 boundary")
    func testT2_23_BottomHalfExactCutoff() {
        let harness = TestHarness()
        harness.updatePreferences { $0.activeArea = .bottomHalf }
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.95, y: 0.50),
            edgeWidth: 0.08,
            activeArea: .bottomHalf
        )
        #expect(edge == .right)
    }

    @Test("T2.24: ActiveArea .bottomHalf rejects touch at y=0.501")
    func testT2_24_BottomHalfJustAboveCutoff() {
        let harness = TestHarness()
        harness.updatePreferences { $0.activeArea = .bottomHalf }
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.95, y: 0.501),
            edgeWidth: 0.08,
            activeArea: .bottomHalf
        )
        #expect(edge == .none)
    }

    @Test("T2.25: ActiveArea .bottomQuarter accepts touch at exact y=0.25 boundary")
    func testT2_25_BottomQuarterExactCutoff() {
        let harness = TestHarness()
        harness.updatePreferences { $0.activeArea = .bottomQuarter }
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.95, y: 0.25),
            edgeWidth: 0.08,
            activeArea: .bottomQuarter
        )
        #expect(edge == .right)
    }

    @Test("T2.26: ActiveArea .bottomQuarter rejects touch at y=0.251")
    func testT2_26_BottomQuarterJustAboveCutoff() {
        let harness = TestHarness()
        harness.updatePreferences { $0.activeArea = .bottomQuarter }
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 0.95, y: 0.251),
            edgeWidth: 0.08,
            activeArea: .bottomQuarter
        )
        #expect(edge == .none)
    }

    // MARK: - Double-Tap Boundaries

    @Test("T2.27: Double tap interval at 290ms (< 300ms) triggers successfully")
    func testT2_27_DoubleTapWithinLimit() {
        let harness = TestHarness(initialVolume: 0.7)
        harness.injectDoubleTap(at: (0.95, 0.95), interval: 0.29)
        #expect(harness.audio.isMuted() == true)
    }

    @Test("T2.28: Double tap interval at 310ms (> 300ms) expires and is rejected")
    func testT2_28_DoubleTapBeyondLimit() {
        let harness = TestHarness(initialVolume: 0.7)
        harness.injectDoubleTap(at: (0.95, 0.95), interval: 0.31)
        #expect(harness.audio.isMuted() == false)
    }

    @Test("T2.29: Double tap spatial distance at 0.038 (< 0.04) triggers successfully")
    func testT2_29_DoubleTapWithinDistance() {
        let harness = TestHarness(initialVolume: 0.7)
        harness.injectDoubleTap(at: (0.95, 0.95), interval: 0.15, secondOffset: (0.035, 0.0))
        #expect(harness.audio.isMuted() == true)
    }

    @Test("T2.30: Double tap spatial distance at 0.045 (> 0.04) is rejected")
    func testT2_30_DoubleTapBeyondDistance() {
        let harness = TestHarness(initialVolume: 0.7)
        harness.injectDoubleTap(at: (0.95, 0.95), interval: 0.15, secondOffset: (0.045, 0.0))
        #expect(harness.audio.isMuted() == false)
    }

    // MARK: - Palm & Multi-Touch Rejection

    @Test("T2.31: Palm touch with large radius (30.0) is rejected")
    func testT2_31_PalmContactRejected() {
        let harness = TestHarness(initialVolume: 0.5)
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch, majorRadius: 30.0, minorRadius: 25.0)
        harness.injectTouch(x: 0.95, y: 0.6, phase: .touching, majorRadius: 30.0, minorRadius: 25.0)
        #expect(harness.audio.getVolume() == 0.5)
        #expect(harness.cursor.isFrozen == false)
    }

    @Test("T2.32: Two simultaneous touches on edge cancel candidate and do not slide")
    func testT2_32_MultiTouchRejection() {
        let harness = TestHarness(initialVolume: 0.5)
        let t1 = SyntheticTouch(id: 1, position: MTPoint(x: 0.95, y: 0.4), phase: .touching)
        let t2 = SyntheticTouch(id: 2, position: MTPoint(x: 0.95, y: 0.6), phase: .touching)
        harness.coordinator.injectTouches([t1, t2])
        #expect(harness.cursor.isFrozen == false)
        #expect(harness.audio.getVolume() == 0.5)
    }

    // MARK: - Coordinate Extremes & Out of Bounds

    @Test("T2.33: Negative coordinate inputs handled safely without crash")
    func testT2_33_NegativeCoordinatesHandled() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: -0.1, y: -0.1),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .bottom || edge == .left)
    }

    @Test("T2.34: Overflow coordinate inputs > 1.0 handled safely without crash")
    func testT2_34_OverflowCoordinatesHandled() {
        let harness = TestHarness()
        let edge = harness.coordinator.gestureEngine.classifyEdge(
            point: MTPoint(x: 1.1, y: 1.1),
            edgeWidth: 0.08,
            activeArea: .entire
        )
        #expect(edge == .topRightCorner)
    }

    @Test("T2.35: Zero delta frame during active slide maintains sliding state without divide by zero")
    func testT2_35_ZeroDeltaFrameMaintainsState() {
        let harness = TestHarness(initialVolume: 0.5)
        harness.injectTouch(x: 0.95, y: 0.5, phase: .makeTouch)
        harness.injectTouch(x: 0.95, y: 0.55, phase: .touching)
        // Stationary frame at exact same position
        harness.injectTouch(x: 0.95, y: 0.55, phase: .touching)
        harness.assertCursorFrozen(true)
    }
}
