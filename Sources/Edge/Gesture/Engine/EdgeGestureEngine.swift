// Sources/Edge/Gesture/Engine/EdgeGestureEngine.swift
import Foundation
import CoreGraphics

// MARK: - Edge Location & Action Enums

/// Physical edge zones on the multitouch surface.
public enum EdgeLocation: String, Sendable, Equatable, Codable {
    case left
    case right
    case bottom
    case topRightCorner
    case none
}

/// Gesture actions emitted by the Edge Gesture Engine.
public enum EdgeGestureAction: Sendable, Equatable {
    case volumeDelta(Float)
    case brightnessDelta(Float)
    case quickMute
    case mediaPlayPause
    case mediaNext
    case mediaPrevious
    case gestureStarted(edge: EdgeLocation)
    case gestureEnded
}

/// Delegate protocol receiving semantic gesture events from EdgeGestureEngine.
public protocol EdgeGestureEngineDelegate: AnyObject, Sendable {
    func handleGestureAction(_ action: EdgeGestureAction)
}

// MARK: - Edge Gesture Engine

/// Production Gesture and Edge Detection Engine for Edge macOS Menu Bar app.
///
/// Implements:
/// - 4-State FSM (Idle -> Candidate -> Sliding -> Ending)
/// - Normalized boundary classification (Left, Right, Bottom media strip, Top-Right Quick Mute)
/// - Active Area Zone filtering on Y-axis with emergency corner bypass
/// - Deadzone filtering (0.02) and perpendicular cancellation (3x deadzone = 0.06)
/// - Palm and multi-touch rejection (> 20.0mm major/minor radius or touch count > 1)
/// - Double-tap detection (< 0.25s tap duration, < 0.30s interval, < 0.04 spatial drift)
/// - Value scaling with sensitivity and precision factor (0.25x for Shift+Option or preciseSliding)
/// - Media swipe track skipping with configurable direction inversion
/// - Discretized haptic step calculation (1/16th or 1/64th increments)
public final class EdgeGestureEngine: @unchecked Sendable {
    public weak var delegate: (any EdgeGestureEngineDelegate)?

    public var bottomMargin: Float = 0.09
    public var cornerMargin: Float = 0.16
    public var deadzone: Float = 0.02
    public var doubleTapMaxInterval: Double = 0.30
    public var doubleTapMaxDistance: Float = 0.04

    private let lock = NSLock()
    public private(set) var currentState: GestureState = .idle
    private var lastTapLocation: MTPoint?
    private var lastTapTime: Double = 0
    private var shiftOptionHeld: Bool = false
    private var activeGestureFingerCount: Int = 1

    public init(delegate: (any EdgeGestureEngineDelegate)? = nil) {
        self.delegate = delegate
    }

    // MARK: - Modifier State Management

    /// Software hook for unit and E2E tests to simulate hardware modifier state.
    public func setShiftOptionModifier(_ held: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self.shiftOptionHeld = held
    }

    /// Evaluates hardware modifier flags from WindowServer session state.
    public static func isHardwareShiftOptionHeld() -> Bool {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        return flags.contains(.maskShift) && flags.contains(.maskAlternate)
    }

    private var isPrecisionModifierActive: Bool {
        shiftOptionHeld || Self.isHardwareShiftOptionHeld()
    }

    // MARK: - Frame Processing Entry Points

    /// Primary frame processing entry point accepting SyntheticTouch array.
    public func processFrame(
        touches: [SyntheticTouch],
        preferences: PreferencesSnapshot,
        cursorManager: (any CursorControlling)?,
        hapticsManager: (any HapticsPerforming)?
    ) {
        lock.lock()
        defer { lock.unlock() }

        // Filter touches: Magic Mouse check
        let validTouches = touches.filter { touch in
            if !touch.isBuiltIn && !preferences.enableMagicMouse {
                return false
            }
            return true
        }

        // 0 Touches: Lift
        if validTouches.isEmpty {
            if case .sliding = currentState {
                endCurrentGesture(cursorManager: cursorManager)
            } else if case .candidate = currentState {
                currentState = .idle
            }
            return
        }

        // > 2 Touches: Multi-touch rejection (pinch, 3/4-finger gestures, large palm)
        if validTouches.count > 2 {
            if case .sliding = currentState {
                endCurrentGesture(cursorManager: cursorManager)
            }
            currentState = .idle
            return
        }

        // MARK: - 2 Touches: Two-Finger Edge Sliding
        if validTouches.count == 2 {
            let t1 = validTouches[0]
            let t2 = validTouches[1]

            // If we were in a 1-finger slide and a second finger arrived, cancel the 1-finger slide
            if case .sliding = currentState, activeGestureFingerCount == 1 {
                endCurrentGesture(cursorManager: cursorManager)
                currentState = .idle
                return
            }

            // Palm rejection
            if t1.majorRadius > 20.0 || t2.majorRadius > 20.0 || t1.minorRadius > 20.0 || t2.minorRadius > 20.0 {
                if case .sliding = currentState {
                    endCurrentGesture(cursorManager: cursorManager)
                }
                currentState = .idle
                return
            }

            // Reject if fingers are too far apart (e.g. fingers on opposite edges)
            let fingerDist = distance(t1.position, t2.position)
            if fingerDist > 0.25 {
                if case .sliding = currentState {
                    endCurrentGesture(cursorManager: cursorManager)
                }
                currentState = .idle
                return
            }

            let centroid = MTPoint(x: (t1.position.x + t2.position.x) / 2.0, y: (t1.position.y + t2.position.y) / 2.0)
            let edgeWidth = Float(preferences.edgeWidth)
            let edge = classifyTwoFingerEdge(t1: t1, t2: t2, centroid: centroid, edgeWidth: edgeWidth, activeArea: preferences.activeArea)

            let isAnyLifted = t1.phase.isLifted || t2.phase.isLifted
            let isAnyMake = t1.phase == .makeTouch || t2.phase == .makeTouch || t1.phase == .startInRange || t2.phase == .startInRange

            if isAnyLifted {
                if case .sliding = currentState {
                    endCurrentGesture(cursorManager: cursorManager)
                }
                currentState = .idle
                return
            }

            if isAnyMake {
                if edge != .none {
                    activeGestureFingerCount = 2
                    currentState = .candidate(edge: edge, startPoint: centroid, startTime: max(t1.timestamp, t2.timestamp))
                } else {
                    if case .sliding = currentState {
                        endCurrentGesture(cursorManager: cursorManager)
                    }
                    currentState = .idle
                }
                return
            }

            // Touching / dragging with 2 fingers
            switch currentState {
            case .idle:
                if edge != .none {
                    activeGestureFingerCount = 2
                    currentState = .candidate(edge: edge, startPoint: centroid, startTime: max(t1.timestamp, t2.timestamp))
                }
            case .candidate(let candEdge, let startPoint, _):
                let dx = centroid.x - startPoint.x
                let dy = centroid.y - startPoint.y

                if candEdge == .left || candEdge == .right {
                    if abs(dy) > deadzone {
                        cursorManager?.freezeCursor(at: CGPoint(x: CGFloat(centroid.x), y: CGFloat(centroid.y)))
                        delegate?.handleGestureAction(.gestureStarted(edge: candEdge))

                        let sensitivity = Float(preferences.sensitivity)
                        let precision = (preferences.preciseSliding || isPrecisionModifierActive) ? Float(0.25) : Float(1.0)
                        let scaledDy = dy * sensitivity * precision

                        let isRight = (candEdge == .right)
                        let isVolumeTarget = preferences.swapSides ? !isRight : isRight

                        if isVolumeTarget {
                            delegate?.handleGestureAction(.volumeDelta(scaledDy))
                        } else {
                            delegate?.handleGestureAction(.brightnessDelta(scaledDy))
                        }

                        var initialHapticStep: Float = 0
                        if preferences.enableHaptics {
                            let stepSize: Float = (preferences.preciseSliding || isPrecisionModifierActive) ? (1.0 / 64.0) : (1.0 / 16.0)
                            let currentStep = scaledDy / stepSize
                            let ticks = Int(abs(currentStep))
                            for _ in 0..<ticks {
                                hapticsManager?.performTick()
                            }
                            initialHapticStep = currentStep.rounded(.towardZero)
                        }

                        activeGestureFingerCount = 2
                        currentState = .sliding(edge: candEdge, lastPoint: centroid, accumulatedDelta: scaledDy, lastHapticStep: initialHapticStep)
                    } else if abs(dx) > deadzone * 2 && abs(dx) > abs(dy) * 1.5 {
                        currentState = .idle
                    }
                } else if candEdge == .bottom {
                    if abs(dx) > deadzone {
                        activeGestureFingerCount = 2
                        currentState = .sliding(edge: candEdge, lastPoint: centroid, accumulatedDelta: 0, lastHapticStep: 0)
                        cursorManager?.freezeCursor(at: CGPoint(x: CGFloat(centroid.x), y: CGFloat(centroid.y)))
                        delegate?.handleGestureAction(.gestureStarted(edge: candEdge))
                    } else if abs(dy) > deadzone * 2 && abs(dy) > abs(dx) * 1.5 {
                        currentState = .idle
                    }
                }

            case .sliding(let slideEdge, let lastPoint, var accumulated, var lastHapticStep):
                let dy = centroid.y - lastPoint.y
                let dx = centroid.x - lastPoint.x

                if (slideEdge == .left || slideEdge == .right) && abs(dx) > deadzone * 3 {
                    endCurrentGesture(cursorManager: cursorManager)
                    return
                } else if slideEdge == .bottom && abs(dy) > deadzone * 3 {
                    endCurrentGesture(cursorManager: cursorManager)
                    return
                }

                let sensitivity = Float(preferences.sensitivity)
                let precision = (preferences.preciseSliding || isPrecisionModifierActive) ? Float(0.25) : Float(1.0)

                if slideEdge == .left || slideEdge == .right {
                    let scaledDy = dy * sensitivity * precision
                    accumulated += scaledDy

                    let isRight = (slideEdge == .right)
                    let isVolumeTarget = preferences.swapSides ? !isRight : isRight

                    if isVolumeTarget {
                        delegate?.handleGestureAction(.volumeDelta(scaledDy))
                    } else {
                        delegate?.handleGestureAction(.brightnessDelta(scaledDy))
                    }

                    if preferences.enableHaptics {
                        let stepSize: Float = (preferences.preciseSliding || isPrecisionModifierActive) ? (1.0 / 64.0) : (1.0 / 16.0)
                        let currentStep = accumulated / stepSize
                        if abs(currentStep - lastHapticStep) >= 1.0 {
                            let ticksToFire = Int(abs(currentStep - lastHapticStep))
                            for _ in 0..<ticksToFire {
                                hapticsManager?.performTick()
                            }
                            lastHapticStep = currentStep.rounded(.towardZero)
                        }
                    }

                    currentState = .sliding(edge: slideEdge, lastPoint: centroid, accumulatedDelta: accumulated, lastHapticStep: lastHapticStep)
                } else if slideEdge == .bottom {
                    let scaledDx = dx * sensitivity * precision
                    accumulated += scaledDx

                    let skipThreshold: Float = 0.15
                    if abs(accumulated) >= skipThreshold {
                        let swipeRight = accumulated > 0
                        accumulated = 0
                        if preferences.reverseMediaSwipe {
                            if swipeRight {
                                delegate?.handleGestureAction(.mediaPrevious)
                            } else {
                                delegate?.handleGestureAction(.mediaNext)
                            }
                        } else {
                            if swipeRight {
                                delegate?.handleGestureAction(.mediaNext)
                            } else {
                                delegate?.handleGestureAction(.mediaPrevious)
                            }
                        }
                    }
                    currentState = .sliding(edge: slideEdge, lastPoint: centroid, accumulatedDelta: accumulated, lastHapticStep: lastHapticStep)
                }

            case .ending:
                currentState = .idle
            }
            return
        }

        // MARK: - 1 Touch: Single-Finger Processing
        let touch = validTouches[0]

        // Palm rejection: large contact patch (> 20.0mm)
        if touch.majorRadius > 20.0 || touch.minorRadius > 20.0 {
            if case .sliding = currentState {
                endCurrentGesture(cursorManager: cursorManager)
            }
            currentState = .idle
            return
        }

        // If we were in a two-finger slide and dropped to 1 finger, end gesture
        if case .sliding = currentState, activeGestureFingerCount == 2 {
            endCurrentGesture(cursorManager: cursorManager)
            return
        }

        let p = touch.position
        let edgeWidth = Float(preferences.edgeWidth)

        switch touch.phase {
        case .makeTouch, .startInRange:
            let edge = classifyEdge(point: p, edgeWidth: edgeWidth, activeArea: preferences.activeArea)
            if edge != .none {
                if preferences.requireTwoFingerSlide {
                    // Only allow candidate for single-finger tap actions (Quick Mute & Play/Pause)
                    if edge == .topRightCorner || edge == .bottom {
                        currentState = .candidate(edge: edge, startPoint: p, startTime: touch.timestamp)
                    } else {
                        currentState = .idle
                    }
                } else {
                    currentState = .candidate(edge: edge, startPoint: p, startTime: touch.timestamp)
                }
            } else {
                currentState = .idle
            }

        case .touching:
            switch currentState {
            case .idle:
                let edge = classifyEdge(point: p, edgeWidth: edgeWidth, activeArea: preferences.activeArea)
                if edge != .none {
                    if preferences.requireTwoFingerSlide {
                        if edge == .topRightCorner || edge == .bottom {
                            currentState = .candidate(edge: edge, startPoint: p, startTime: touch.timestamp)
                        }
                    } else {
                        currentState = .candidate(edge: edge, startPoint: p, startTime: touch.timestamp)
                    }
                }

            case .candidate(let edge, let startPoint, _):
                let dx = p.x - startPoint.x
                let dy = p.y - startPoint.y

                if preferences.requireTwoFingerSlide {
                    // Two-finger slide is required for volume/brightness sliders.
                    // If a single finger moves significantly, cancel candidate so cursor remains completely free.
                    if abs(dx) > deadzone * 2 || abs(dy) > deadzone * 2 {
                        currentState = .idle
                    }
                } else {
                    if edge == .bottom {
                        if abs(dx) > deadzone {
                            currentState = .sliding(edge: edge, lastPoint: p, accumulatedDelta: 0, lastHapticStep: 0)
                            cursorManager?.freezeCursor(at: CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)))
                            delegate?.handleGestureAction(.gestureStarted(edge: edge))
                        } else if abs(dy) > deadzone * 2 && abs(dy) > abs(dx) * 1.5 {
                            currentState = .idle
                        }
                    } else if edge == .left || edge == .right || edge == .topRightCorner {
                        let canSlide: Bool
                        let effectiveEdge: EdgeLocation
                        if edge == .topRightCorner {
                            effectiveEdge = .right
                            canSlide = (startPoint.y <= Float(preferences.activeArea.maxY)) || (preferences.activeArea == .entire)
                        } else {
                            effectiveEdge = edge
                            canSlide = true
                        }

                        if canSlide && abs(dy) > deadzone {
                            cursorManager?.freezeCursor(at: CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)))
                            delegate?.handleGestureAction(.gestureStarted(edge: effectiveEdge))

                            let sensitivity = Float(preferences.sensitivity)
                            let precision = (preferences.preciseSliding || isPrecisionModifierActive) ? Float(0.25) : Float(1.0)
                            let scaledDy = dy * sensitivity * precision

                            let isRight = (effectiveEdge == .right)
                            let isVolumeTarget = preferences.swapSides ? !isRight : isRight

                            if isVolumeTarget {
                                delegate?.handleGestureAction(.volumeDelta(scaledDy))
                            } else {
                                delegate?.handleGestureAction(.brightnessDelta(scaledDy))
                            }

                            var initialHapticStep: Float = 0
                            if preferences.enableHaptics {
                                let stepSize: Float = (preferences.preciseSliding || isPrecisionModifierActive) ? (1.0 / 64.0) : (1.0 / 16.0)
                                let currentStep = scaledDy / stepSize
                                let ticks = Int(abs(currentStep))
                                for _ in 0..<ticks {
                                    hapticsManager?.performTick()
                                }
                                initialHapticStep = currentStep.rounded(.towardZero)
                            }

                            currentState = .sliding(edge: effectiveEdge, lastPoint: p, accumulatedDelta: scaledDy, lastHapticStep: initialHapticStep)
                        } else if abs(dx) > deadzone * 2 && abs(dx) > abs(dy) * 1.5 {
                            currentState = .idle
                        }
                    }
                }

            case .sliding(let edge, let lastPoint, var accumulated, var lastHapticStep):
                let dy = p.y - lastPoint.y
                let dx = p.x - lastPoint.x

                // Perpendicular cancellation check (> 3x deadzone = 0.06)
                if (edge == .left || edge == .right) && abs(dx) > deadzone * 3 {
                    endCurrentGesture(cursorManager: cursorManager)
                    return
                } else if edge == .bottom && abs(dy) > deadzone * 3 {
                    endCurrentGesture(cursorManager: cursorManager)
                    return
                }

                let sensitivity = Float(preferences.sensitivity)
                let precision = (preferences.preciseSliding || isPrecisionModifierActive) ? Float(0.25) : Float(1.0)

                if edge == .bottom {
                    // Media swipe
                    let scaledDx = dx * sensitivity * precision
                    accumulated += scaledDx

                    let skipThreshold: Float = 0.15
                    if abs(accumulated) >= skipThreshold {
                        let swipeRight = accumulated > 0
                        accumulated = 0
                        if preferences.reverseMediaSwipe {
                            if swipeRight {
                                delegate?.handleGestureAction(.mediaPrevious)
                            } else {
                                delegate?.handleGestureAction(.mediaNext)
                            }
                        } else {
                            if swipeRight {
                                delegate?.handleGestureAction(.mediaNext)
                            } else {
                                delegate?.handleGestureAction(.mediaPrevious)
                            }
                        }
                    }
                    currentState = .sliding(edge: edge, lastPoint: p, accumulatedDelta: accumulated, lastHapticStep: lastHapticStep)

                } else if edge == .left || edge == .right {
                    // Vertical slider (Volume / Brightness)
                    let scaledDy = dy * sensitivity * precision
                    accumulated += scaledDy

                    let isRight = (edge == .right)
                    let isVolumeTarget = preferences.swapSides ? !isRight : isRight

                    if isVolumeTarget {
                        delegate?.handleGestureAction(.volumeDelta(scaledDy))
                    } else {
                        delegate?.handleGestureAction(.brightnessDelta(scaledDy))
                    }

                    // Haptics calculation: discrete steps
                    if preferences.enableHaptics {
                        let stepSize: Float = (preferences.preciseSliding || isPrecisionModifierActive) ? (1.0 / 64.0) : (1.0 / 16.0)
                        let currentStep = accumulated / stepSize
                        if abs(currentStep - lastHapticStep) >= 1.0 {
                            let ticksToFire = Int(abs(currentStep - lastHapticStep))
                            for _ in 0..<ticksToFire {
                                hapticsManager?.performTick()
                            }
                            lastHapticStep = currentStep.rounded(.towardZero)
                        }
                    }

                    currentState = .sliding(edge: edge, lastPoint: p, accumulatedDelta: accumulated, lastHapticStep: lastHapticStep)
                }

            case .ending:
                currentState = .idle
            }

        case .breakTouch, .notTracking, .outOfRange:
            handleTouchLift(
                touch: touch,
                preferences: preferences,
                cursorManager: cursorManager,
                hapticsManager: hapticsManager
            )

        case .hoverInRange, .lingerInRange:
            break
        }
    }

    /// Convenience overload accepting raw MTTouch array from MultitouchBridge.
    public func processFrame(
        touches: [MTTouch],
        isBuiltIn: Bool = true,
        preferences: PreferencesSnapshot,
        cursorManager: (any CursorControlling)?,
        hapticsManager: (any HapticsPerforming)?
    ) {
        let synthetic = touches.map { SyntheticTouch(from: $0, isBuiltIn: isBuiltIn) }
        processFrame(
            touches: synthetic,
            preferences: preferences,
            cursorManager: cursorManager,
            hapticsManager: hapticsManager
        )
    }

    // MARK: - Touch Lift & Gesture Teardown

    private func handleTouchLift(
        touch: SyntheticTouch,
        preferences: PreferencesSnapshot,
        cursorManager: (any CursorControlling)?,
        hapticsManager: (any HapticsPerforming)?
    ) {
        switch currentState {
        case .sliding:
            endCurrentGesture(cursorManager: cursorManager)

        case .candidate(let edge, let startPoint, let startTime):
            let dt = touch.timestamp - startTime
            let dist = distance(touch.position, startPoint)

            // Double tap check: duration < 0.25s, movement < 0.04
            if dt < 0.25 && dist < doubleTapMaxDistance {
                if let lastLoc = lastTapLocation,
                   (touch.timestamp - lastTapTime) < doubleTapMaxInterval,
                   distance(touch.position, lastLoc) < doubleTapMaxDistance {
                    // Double tap confirmed!
                    if edge == .topRightCorner {
                        delegate?.handleGestureAction(.quickMute)
                        hapticsManager?.performTick()
                    } else if edge == .bottom {
                        delegate?.handleGestureAction(.mediaPlayPause)
                        hapticsManager?.performTick()
                    }
                    lastTapLocation = nil
                    lastTapTime = 0
                } else {
                    lastTapLocation = touch.position
                    lastTapTime = touch.timestamp
                }
            }
            currentState = .idle

        case .idle, .ending:
            currentState = .idle
        }
    }

    private func endCurrentGesture(cursorManager: (any CursorControlling)?) {
        cursorManager?.unfreezeCursor()
        delegate?.handleGestureAction(.gestureEnded)
        currentState = .idle
        lastTapLocation = nil
        lastTapTime = 0
        activeGestureFingerCount = 1
    }

    /// Resets the engine state, unfreezing cursor and clearing tap memory.
    public func reset(cursorManager: (any CursorControlling)? = nil) {
        lock.lock()
        defer { lock.unlock() }
        if case .sliding = currentState {
            cursorManager?.unfreezeCursor()
            delegate?.handleGestureAction(.gestureEnded)
        }
        currentState = .idle
        lastTapLocation = nil
        lastTapTime = 0
        shiftOptionHeld = false
        activeGestureFingerCount = 1
    }

    // MARK: - Boundary Classification Math

    /// Evaluates normalized trackpad coordinates to identify active edge zone.
    public func classifyEdge(point: MTPoint, edgeWidth: Float, activeArea: ActiveAreaZone) -> EdgeLocation {
        // Active area zone check on Y axis
        if point.y > Float(activeArea.maxY) {
            // Outside active area! Except for top-right corner quick mute if point is in corner
            if point.x >= (1.0 - cornerMargin - 0.001) && point.y >= (1.0 - cornerMargin - 0.001) {
                return .topRightCorner
            }
            return .none
        }

        // Top-right corner quick mute: x >= 1.0 - cornerMargin && y >= 1.0 - cornerMargin
        if point.x >= (1.0 - cornerMargin - 0.001) && point.y >= (1.0 - cornerMargin - 0.001) {
            return .topRightCorner
        }

        // Bottom edge media strip: y <= bottomMargin
        if point.y <= bottomMargin {
            return .bottom
        }

        // Right edge
        if point.x >= (1.0 - edgeWidth) {
            return .right
        }

        // Left edge
        if point.x <= edgeWidth {
            return .left
        }

        return .none
    }

    /// Evaluates whether two touches represent a coherent edge gesture (e.g. Volume/Brightness slide).
    public func classifyTwoFingerEdge(
        t1: SyntheticTouch,
        t2: SyntheticTouch,
        centroid: MTPoint,
        edgeWidth: Float,
        activeArea: ActiveAreaZone
    ) -> EdgeLocation {
        // Both on right half
        if t1.position.x > 0.5 && t2.position.x > 0.5 {
            let rightThreshold = 1.0 - edgeWidth
            let expandedThreshold = 1.0 - max(edgeWidth * 1.5, 0.12)
            let isNearRight = t1.position.x >= rightThreshold
                || t2.position.x >= rightThreshold
                || centroid.x >= expandedThreshold

            if isNearRight {
                if centroid.y <= Float(activeArea.maxY) || activeArea == .entire || centroid.y >= (1.0 - cornerMargin) {
                    return .right
                }
            }
        } else if t1.position.x < 0.5 && t2.position.x < 0.5 {
            // Both on left half
            let leftThreshold = edgeWidth
            let expandedThreshold = max(edgeWidth * 1.5, 0.12)
            let isNearLeft = t1.position.x <= leftThreshold
                || t2.position.x <= leftThreshold
                || centroid.x <= expandedThreshold

            if isNearLeft {
                if centroid.y <= Float(activeArea.maxY) || activeArea == .entire {
                    return .left
                }
            }
        } else if t1.position.y < 0.5 && t2.position.y < 0.5 {
            // Both on bottom
            if centroid.y <= bottomMargin * 1.5 || t1.position.y <= bottomMargin || t2.position.y <= bottomMargin {
                return .bottom
            }
        }

        return .none
    }

    private func distance(_ a: MTPoint, _ b: MTPoint) -> Float {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
}
