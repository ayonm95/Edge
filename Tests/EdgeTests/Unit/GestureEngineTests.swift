// Tests/EdgeTests/Unit/GestureEngineTests.swift
import Testing
import Foundation
import CoreGraphics
@testable import Edge

@Suite("Gesture Engine Unit Tests", .serialized)
struct GestureEngineTests {

    final class SpyGestureDelegate: Edge.EdgeGestureEngineDelegate, @unchecked Sendable {
        private let lock = NSLock()
        private var _actions: [Edge.EdgeGestureAction] = []

        func handleGestureAction(_ action: Edge.EdgeGestureAction) {
            lock.lock()
            defer { lock.unlock() }
            _actions.append(action)
        }

        var actions: [Edge.EdgeGestureAction] {
            lock.lock()
            defer { lock.unlock() }
            return _actions
        }

        func clear() {
            lock.lock()
            defer { lock.unlock() }
            _actions.removeAll()
        }
    }

    // MARK: - 1. FSM State Lifecycle & Transitions

    @Test("FSM transitions: Idle -> Candidate -> Sliding -> Ending -> Idle")
    func fsmStateTransitions() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)
        let prefs = Edge.PreferencesSnapshot.default

        #expect(engine.currentState == .idle)

        // 1. Initial touch on right edge -> enters .candidate
        let t1 = Edge.SyntheticTouch(
            position: Edge.MTPoint(x: 0.95, y: 0.50),
            phase: .makeTouch,
            timestamp: 10.0
        )
        engine.processFrame(touches: [t1], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        if case .candidate(let edge, let startPoint, _) = engine.currentState {
            #expect(edge == .right)
            #expect(startPoint.x == 0.95)
            #expect(startPoint.y == 0.50)
        } else {
            Issue.record("Expected .candidate state after makeTouch")
        }

        // 2. Small sub-deadzone movement (0.015 <= 0.02) -> stays in .candidate
        let t2 = Edge.SyntheticTouch(
            position: Edge.MTPoint(x: 0.95, y: 0.515),
            phase: .touching,
            timestamp: 10.02
        )
        engine.processFrame(touches: [t2], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        if case .candidate = engine.currentState {
            #expect(cursor.isFrozen == false)
        } else {
            Issue.record("Expected to remain in .candidate below deadzone")
        }

        // 3. Movement exceeding deadzone (dy = 0.035 > 0.02) -> enters .sliding and freezes cursor
        let t3 = Edge.SyntheticTouch(
            position: Edge.MTPoint(x: 0.95, y: 0.535),
            phase: .touching,
            timestamp: 10.04
        )
        engine.processFrame(touches: [t3], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        if case .sliding(let edge, let lastPoint, _, _) = engine.currentState {
            #expect(edge == .right)
            #expect(lastPoint.y == 0.535)
            #expect(cursor.isFrozen == true)
        } else {
            Issue.record("Expected .sliding state above deadzone")
        }
        #expect(spy.actions.contains(.gestureStarted(edge: .right)))

        // 4. Touch lift -> unfreezes cursor, emits gestureEnded, resets to .idle
        let t4 = Edge.SyntheticTouch(
            position: Edge.MTPoint(x: 0.95, y: 0.535),
            phase: .breakTouch,
            timestamp: 10.10
        )
        engine.processFrame(touches: [t4], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        #expect(engine.currentState == .idle)
        #expect(cursor.isFrozen == false)
        #expect(spy.actions.contains(.gestureEnded))
    }

    // MARK: - 2. Boundary Classification & Active Area Math

    @Test("Boundary classification for edge zones")
    func boundaryClassification() {
        let engine = Edge.EdgeGestureEngine()

        // Left edge (x <= 0.08)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.05, y: 0.50), edgeWidth: 0.08, activeArea: .entire) == .left)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.080, y: 0.50), edgeWidth: 0.08, activeArea: .entire) == .left)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.081, y: 0.50), edgeWidth: 0.08, activeArea: .entire) == .none)

        // Right edge (x >= 1.0 - 0.08 = 0.92)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.95, y: 0.50), edgeWidth: 0.08, activeArea: .entire) == .right)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.920, y: 0.50), edgeWidth: 0.08, activeArea: .entire) == .right)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.919, y: 0.50), edgeWidth: 0.08, activeArea: .entire) == .none)

        // Bottom edge (y <= 0.09)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.50, y: 0.05), edgeWidth: 0.08, activeArea: .entire) == .bottom)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.50, y: 0.090), edgeWidth: 0.08, activeArea: .entire) == .bottom)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.50, y: 0.091), edgeWidth: 0.08, activeArea: .entire) == .none)

        // Origin (0.0, 0.0) classifies as .bottom (bottomMargin checked before left edge)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.0, y: 0.0), edgeWidth: 0.08, activeArea: .entire) == .bottom)

        // Center is .none
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.50, y: 0.50), edgeWidth: 0.08, activeArea: .entire) == .none)

        // Top-right corner (x >= 0.839 && y >= 0.839)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.84, y: 0.84), edgeWidth: 0.08, activeArea: .entire) == .topRightCorner)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 1.0, y: 1.0), edgeWidth: 0.08, activeArea: .entire) == .topRightCorner)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.838, y: 0.85), edgeWidth: 0.08, activeArea: .entire) == .none)
    }

    @Test("Active Area restrictions with corner bypass")
    func activeAreaRestrictionsAndCornerBypass() {
        let engine = Edge.EdgeGestureEngine()

        // ActiveArea .bottomHalf (maxY = 0.50)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.05, y: 0.40), edgeWidth: 0.08, activeArea: .bottomHalf) == .left)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.05, y: 0.50), edgeWidth: 0.08, activeArea: .bottomHalf) == .left)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.05, y: 0.51), edgeWidth: 0.08, activeArea: .bottomHalf) == .none)

        // ActiveArea .bottomQuarter (maxY = 0.25)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.05, y: 0.25), edgeWidth: 0.08, activeArea: .bottomQuarter) == .left)
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.05, y: 0.26), edgeWidth: 0.08, activeArea: .bottomQuarter) == .none)

        // Corner bypass: even with .bottomQuarter (maxY = 0.25), top-right corner is accepted!
        #expect(engine.classifyEdge(point: Edge.MTPoint(x: 0.95, y: 0.95), edgeWidth: 0.08, activeArea: .bottomQuarter) == .topRightCorner)
    }

    // MARK: - 3. Palm & Multi-Touch Rejection

    @Test("Palm rejection for large contact radius")
    func palmRejectionLargeRadius() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)
        let prefs = Edge.PreferencesSnapshot.default

        // Large contact radius (> 20.0mm) representing resting palm
        let palmTouch = Edge.SyntheticTouch(
            position: Edge.MTPoint(x: 0.05, y: 0.50),
            phase: .makeTouch,
            majorRadius: 25.0,
            minorRadius: 22.0
        )
        engine.processFrame(touches: [palmTouch], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        #expect(engine.currentState == .idle)
        #expect(cursor.isFrozen == false)
    }

    @Test("Multi-touch count > 1 cancels sliding gesture")
    func multiTouchRejection() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)
        let prefs = Edge.PreferencesSnapshot.default

        // Start slide
        let t1 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.50), phase: .makeTouch, timestamp: 1.0)
        let t2 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.55), phase: .touching, timestamp: 1.02)
        engine.processFrame(touches: [t1], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [t2], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        if case .sliding = engine.currentState {} else { Issue.record("Must be sliding") }

        // Second finger arrives (pinch/scroll attempt) -> cancels sliding
        let finger1 = Edge.SyntheticTouch(id: 1, position: Edge.MTPoint(x: 0.95, y: 0.56), phase: .touching, timestamp: 1.04)
        let finger2 = Edge.SyntheticTouch(id: 2, position: Edge.MTPoint(x: 0.80, y: 0.50), phase: .touching, timestamp: 1.04)
        engine.processFrame(touches: [finger1, finger2], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        #expect(engine.currentState == .idle)
        #expect(cursor.isFrozen == false)
        #expect(spy.actions.contains(.gestureEnded))
    }

    // MARK: - 4. Inward Perpendicular Cancellation

    @Test("Perpendicular inward swipe > 3x deadzone (0.06) terminates sliding")
    func perpendicularInwardCancellation() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)
        let prefs = Edge.PreferencesSnapshot.default

        // Enter sliding on right edge
        let t1 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.50), phase: .makeTouch, timestamp: 1.0)
        let t2 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.54), phase: .touching, timestamp: 1.02)
        engine.processFrame(touches: [t1], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [t2], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        if case .sliding = engine.currentState {} else { Issue.record("Must be sliding") }

        // Swipe inward horizontally onto trackpad canvas (dx = -0.07 > 0.06 cutoff)
        let t3 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.88, y: 0.54), phase: .touching, timestamp: 1.04)
        engine.processFrame(touches: [t3], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        #expect(engine.currentState == .idle)
        #expect(cursor.isFrozen == false)
        #expect(spy.actions.contains(.gestureEnded))
    }

    // MARK: - 5. Double-Tap Detection

    @Test("Double-tap in top-right corner triggers quickMute")
    func doubleTapQuickMute() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)
        let prefs = Edge.PreferencesSnapshot.default

        // Tap 1
        let tap1Down = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.95), phase: .makeTouch, timestamp: 1.0)
        let tap1Up = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.95), phase: .breakTouch, timestamp: 1.08)
        engine.processFrame(touches: [tap1Down], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [tap1Up], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        #expect(spy.actions.isEmpty)

        // Tap 2 (interval = 0.12s < 0.30s)
        let tap2Down = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.96), phase: .makeTouch, timestamp: 1.20)
        let tap2Up = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.96), phase: .breakTouch, timestamp: 1.28)
        engine.processFrame(touches: [tap2Down], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [tap2Up], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        #expect(spy.actions.contains(.quickMute))
        #expect(haptics.tickCount >= 1)
    }

    @Test("Double-tap on bottom edge triggers mediaPlayPause")
    func doubleTapMediaPlayPause() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)
        let prefs = Edge.PreferencesSnapshot.default

        // Tap 1
        let tap1Down = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.50, y: 0.04), phase: .makeTouch, timestamp: 2.0)
        let tap1Up = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.50, y: 0.04), phase: .breakTouch, timestamp: 2.06)
        engine.processFrame(touches: [tap1Down], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [tap1Up], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        // Tap 2
        let tap2Down = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.51, y: 0.04), phase: .makeTouch, timestamp: 2.18)
        let tap2Up = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.51, y: 0.04), phase: .breakTouch, timestamp: 2.24)
        engine.processFrame(touches: [tap2Down], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [tap2Up], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        #expect(spy.actions.contains(.mediaPlayPause))
        #expect(haptics.tickCount >= 1)
    }

    // MARK: - 6. Side Swapping & Precision Factors

    @Test("Side swapping switches Volume and Brightness edges")
    func sideSwapping() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)

        // Normal (swapSides: false): Right edge = volume
        let prefsNormal = Edge.PreferencesSnapshot(swapSides: false)
        let r1 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.50), phase: .makeTouch, timestamp: 1.0)
        let r2 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.55), phase: .touching, timestamp: 1.02)
        engine.processFrame(touches: [r1], preferences: prefsNormal, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [r2], preferences: prefsNormal, cursorManager: cursor, hapticsManager: haptics)

        let hadVolume = spy.actions.contains { action in
            if case .volumeDelta = action { return true }
            return false
        }
        #expect(hadVolume)

        engine.reset(cursorManager: cursor)
        spy.clear()

        // Swapped (swapSides: true): Right edge = brightness
        let prefsSwapped = Edge.PreferencesSnapshot(swapSides: true)
        let s1 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.50), phase: .makeTouch, timestamp: 2.0)
        let s2 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.55), phase: .touching, timestamp: 2.02)
        engine.processFrame(touches: [s1], preferences: prefsSwapped, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [s2], preferences: prefsSwapped, cursorManager: cursor, hapticsManager: haptics)

        let hadBrightness = spy.actions.contains { action in
            if case .brightnessDelta = action { return true }
            return false
        }
        #expect(hadBrightness)
    }

    @Test("Precision modifier scales delta by 0.25")
    func precisionFactorScaling() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)

        // 1. Normal slide (precision = 1.0, dy = 0.04)
        let prefsNormal = Edge.PreferencesSnapshot(sensitivity: 1.0, preciseSliding: false)
        let t1 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.50), phase: .makeTouch, timestamp: 1.0)
        let t2 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.54), phase: .touching, timestamp: 1.02)
        engine.processFrame(touches: [t1], preferences: prefsNormal, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [t2], preferences: prefsNormal, cursorManager: cursor, hapticsManager: haptics)

        var normalDelta: Float = 0
        for action in spy.actions {
            if case .volumeDelta(let d) = action { normalDelta = d }
        }
        #expect(abs(normalDelta - 0.04) < 0.001)

        engine.reset(cursorManager: cursor)
        spy.clear()

        // 2. Precise slide via Shift+Option software hook (precision = 0.25, dy = 0.04 -> scaled 0.01)
        engine.setShiftOptionModifier(true)
        let p1 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.50), phase: .makeTouch, timestamp: 2.0)
        let p2 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.54), phase: .touching, timestamp: 2.02)
        engine.processFrame(touches: [p1], preferences: prefsNormal, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [p2], preferences: prefsNormal, cursorManager: cursor, hapticsManager: haptics)

        var preciseDelta: Float = 0
        for action in spy.actions {
            if case .volumeDelta(let d) = action { preciseDelta = d }
        }
        #expect(abs(preciseDelta - 0.01) < 0.001)
    }

    // MARK: - 7. Media Swipe Track Skipping

    @Test("Bottom edge media swipe emits mediaNext and mediaPrevious")
    func bottomEdgeMediaSwipe() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)
        let prefs = Edge.PreferencesSnapshot(reverseMediaSwipe: false)

        // Enter slide on bottom edge
        let t1 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.30, y: 0.05), phase: .makeTouch, timestamp: 1.0)
        let t2 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.33, y: 0.05), phase: .touching, timestamp: 1.02)
        engine.processFrame(touches: [t1], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [t2], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        // Swipe right exceeding skipThreshold (0.15): from 0.33 to 0.50 (dx = 0.17 > 0.15)
        let t3 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.50, y: 0.05), phase: .touching, timestamp: 1.04)
        engine.processFrame(touches: [t3], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        #expect(spy.actions.contains(.mediaNext))

        engine.reset(cursorManager: cursor)
        spy.clear()

        // Reversed media swipe: swipe right emits mediaPrevious
        let prefsReversed = Edge.PreferencesSnapshot(reverseMediaSwipe: true)
        let r1 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.30, y: 0.05), phase: .makeTouch, timestamp: 2.0)
        let r2 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.33, y: 0.05), phase: .touching, timestamp: 2.02)
        let r3 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.50, y: 0.05), phase: .touching, timestamp: 2.04)
        engine.processFrame(touches: [r1], preferences: prefsReversed, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [r2], preferences: prefsReversed, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [r3], preferences: prefsReversed, cursorManager: cursor, hapticsManager: haptics)

        #expect(spy.actions.contains(.mediaPrevious))
    }

    // MARK: - 8. Raw MTTouch Overload

    @Test("EdgeGestureEngine accepts raw MTTouch frames from MultitouchBridge")
    func rawMTTouchOverload() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)
        let prefs = Edge.PreferencesSnapshot.default

        let touch = Edge.MTTouch.makeSynthetic(fingerID: 7, x: 0.95, y: 0.50, phase: .makeTouch, timestamp: 1.0)
        engine.processFrame(touches: [touch], isBuiltIn: true, preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        if case .candidate(let edge, _, _) = engine.currentState {
            #expect(edge == .right)
        } else {
            Issue.record("Expected candidate from raw MTTouch frame")
        }
    }

    // MARK: - 9. Two-Finger Edge Sliding & Single-Finger Mute

    @Test("Two-finger swipe on right edge modulates volume")
    func twoFingerRightEdgeSliding() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)
        let prefs = Edge.PreferencesSnapshot(requireTwoFingerSlide: true)

        let t1 = Edge.SyntheticTouch(id: 1, position: Edge.MTPoint(x: 0.96, y: 0.40), phase: .makeTouch, timestamp: 1.0)
        let t2 = Edge.SyntheticTouch(id: 2, position: Edge.MTPoint(x: 0.90, y: 0.40), phase: .makeTouch, timestamp: 1.0)
        engine.processFrame(touches: [t1, t2], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        if case .candidate(let edge, _, _) = engine.currentState {
            #expect(edge == .right)
        } else {
            Issue.record("Expected candidate state for two fingers on right edge")
        }

        // Drag both fingers upward
        let m1 = Edge.SyntheticTouch(id: 1, position: Edge.MTPoint(x: 0.96, y: 0.45), phase: .touching, timestamp: 1.02)
        let m2 = Edge.SyntheticTouch(id: 2, position: Edge.MTPoint(x: 0.90, y: 0.45), phase: .touching, timestamp: 1.02)
        engine.processFrame(touches: [m1, m2], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        if case .sliding(let edge, _, _, _) = engine.currentState {
            #expect(edge == .right)
        } else {
            Issue.record("Expected sliding state for two fingers on right edge")
        }

        #expect(cursor.isFrozen)
        let hasVolumeDelta = spy.actions.contains { action in
            if case .volumeDelta(let delta) = action, delta > 0 { return true }
            return false
        }
        #expect(hasVolumeDelta)

        // Lift fingers
        let u1 = Edge.SyntheticTouch(id: 1, position: Edge.MTPoint(x: 0.96, y: 0.45), phase: .breakTouch, timestamp: 1.05)
        let u2 = Edge.SyntheticTouch(id: 2, position: Edge.MTPoint(x: 0.90, y: 0.45), phase: .breakTouch, timestamp: 1.05)
        engine.processFrame(touches: [u1, u2], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        #expect(engine.currentState == .idle)
        #expect(!cursor.isFrozen)
        #expect(spy.actions.contains(.gestureEnded))
    }

    @Test("Two-finger swipe on left edge modulates brightness")
    func twoFingerLeftEdgeSliding() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)
        let prefs = Edge.PreferencesSnapshot(requireTwoFingerSlide: true)

        let t1 = Edge.SyntheticTouch(id: 1, position: Edge.MTPoint(x: 0.04, y: 0.40), phase: .makeTouch, timestamp: 1.0)
        let t2 = Edge.SyntheticTouch(id: 2, position: Edge.MTPoint(x: 0.10, y: 0.40), phase: .makeTouch, timestamp: 1.0)
        engine.processFrame(touches: [t1, t2], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        let m1 = Edge.SyntheticTouch(id: 1, position: Edge.MTPoint(x: 0.04, y: 0.46), phase: .touching, timestamp: 1.02)
        let m2 = Edge.SyntheticTouch(id: 2, position: Edge.MTPoint(x: 0.10, y: 0.46), phase: .touching, timestamp: 1.02)
        engine.processFrame(touches: [m1, m2], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        if case .sliding(let edge, _, _, _) = engine.currentState {
            #expect(edge == .left)
        } else {
            Issue.record("Expected sliding state for two fingers on left edge")
        }

        let hasBrightnessDelta = spy.actions.contains { action in
            if case .brightnessDelta(let delta) = action, delta > 0 { return true }
            return false
        }
        #expect(hasBrightnessDelta)
    }

    @Test("Single-finger drag does NOT slide when requireTwoFingerSlide is enabled")
    func singleFingerDragIgnoredWhenRequireTwoFingerSlide() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)
        let prefs = Edge.PreferencesSnapshot(requireTwoFingerSlide: true)

        let t1 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.40), phase: .makeTouch, timestamp: 1.0)
        let t2 = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.55), phase: .touching, timestamp: 1.02)
        engine.processFrame(touches: [t1], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [t2], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        #expect(engine.currentState == .idle)
        #expect(!cursor.isFrozen)
        let hasVolumeDelta = spy.actions.contains { action in
            if case .volumeDelta = action { return true }
            return false
        }
        #expect(!hasVolumeDelta)
    }

    @Test("Single-finger double tap STILL mutes when requireTwoFingerSlide is enabled")
    func singleFingerDoubleTapMutesWhenRequireTwoFingerSlide() {
        let spy = SpyGestureDelegate()
        let engine = Edge.EdgeGestureEngine(delegate: spy)
        let cursor = Edge.CursorManager()
        let haptics = Edge.HapticsManager(minInterval: 0.0)
        let prefs = Edge.PreferencesSnapshot(requireTwoFingerSlide: true)

        // Tap 1
        let tap1Down = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.95), phase: .makeTouch, timestamp: 1.0)
        let tap1Up = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.95), phase: .breakTouch, timestamp: 1.05)
        engine.processFrame(touches: [tap1Down], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [tap1Up], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        #expect(!spy.actions.contains(.quickMute))

        // Tap 2 (0.1s later)
        let tap2Down = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.95), phase: .makeTouch, timestamp: 1.15)
        let tap2Up = Edge.SyntheticTouch(position: Edge.MTPoint(x: 0.95, y: 0.95), phase: .breakTouch, timestamp: 1.20)
        engine.processFrame(touches: [tap2Down], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)
        engine.processFrame(touches: [tap2Up], preferences: prefs, cursorManager: cursor, hapticsManager: haptics)

        #expect(spy.actions.contains(.quickMute))
    }
}
