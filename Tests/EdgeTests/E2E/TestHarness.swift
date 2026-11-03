//
//  TestHarness.swift
//  EdgeTests
//
//  Comprehensive Opaque-Box E2E Test Harness for Edge macOS Application.
//  Provides synthetic touch injection, verifiable mock hardware controllers,
//  HUD state tracking, and assertion helpers across Tiers 1-4.
//

import Foundation
import Testing

// MARK: - Domain Enums & Structs

public enum ActiveAreaZone: String, Sendable, Codable, CaseIterable {
    case entire = "entire"
    case bottomThreeQuarters = "bottomThreeQuarters"
    case bottomHalf = "bottomHalf"
    case bottomQuarter = "bottomQuarter"

    public var maxY: Float {
        switch self {
        case .entire: return 1.0
        case .bottomThreeQuarters: return 0.75
        case .bottomHalf: return 0.50
        case .bottomQuarter: return 0.25
        }
    }
}

public struct PreferencesSnapshot: Sendable, Codable, Equatable {
    public var swapSides: Bool
    public var edgeWidth: Double          // 0.03 - 0.20
    public var sensitivity: Double        // 0.5 - 2.5
    public var activeArea: ActiveAreaZone
    public var reverseMediaSwipe: Bool
    public var preciseSliding: Bool
    public var enableMagicMouse: Bool
    public var showOSD: Bool
    public var enableHaptics: Bool
    public var requireTwoFingerSlide: Bool

    public static let `default` = PreferencesSnapshot(
        swapSides: false,
        edgeWidth: 0.08,
        sensitivity: 1.0,
        activeArea: .entire,
        reverseMediaSwipe: false,
        preciseSliding: false,
        enableMagicMouse: false,
        showOSD: true,
        enableHaptics: true,
        requireTwoFingerSlide: false
    )

    public init(
        swapSides: Bool = false,
        edgeWidth: Double = 0.08,
        sensitivity: Double = 1.0,
        activeArea: ActiveAreaZone = .entire,
        reverseMediaSwipe: Bool = false,
        preciseSliding: Bool = false,
        enableMagicMouse: Bool = false,
        showOSD: Bool = true,
        enableHaptics: Bool = true,
        requireTwoFingerSlide: Bool = false
    ) {
        self.swapSides = swapSides
        self.edgeWidth = min(max(edgeWidth, 0.03), 0.20)
        self.sensitivity = min(max(sensitivity, 0.5), 2.5)
        self.activeArea = activeArea
        self.reverseMediaSwipe = reverseMediaSwipe
        self.preciseSliding = preciseSliding
        self.enableMagicMouse = enableMagicMouse
        self.showOSD = showOSD
        self.enableHaptics = enableHaptics
        self.requireTwoFingerSlide = requireTwoFingerSlide
    }
}

public final class AtomicPreferencesHolder: @unchecked Sendable {
    private var snapshot: PreferencesSnapshot
    private let lock = NSLock()

    public init(snapshot: PreferencesSnapshot = .default) {
        self.snapshot = snapshot
    }

    public func get() -> PreferencesSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }

    public func set(_ snapshot: PreferencesSnapshot) {
        lock.lock()
        defer { lock.unlock() }
        self.snapshot = snapshot
    }
}

public enum EdgeLocation: String, Sendable, Equatable {
    case left
    case right
    case bottom
    case topRightCorner
    case none
}

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

public enum MediaAction: String, Sendable, Equatable {
    case playPause
    case nextTrack
    case previousTrack
}

public enum HUDType: Equatable, Sendable {
    case volume(level: Float, isMuted: Bool)
    case brightness(level: Float)
    case media(action: MediaAction)
}

public enum StatusIconState: String, Sendable, Equatable {
    case idle
    case active
    case alert
    case disabled
}

// MARK: - Multitouch Contact Structs

public struct MTPoint: Sendable, Equatable {
    public var x: Float
    public var y: Float
    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

public struct MTVector: Sendable, Equatable {
    public var position: MTPoint
    public var velocity: MTPoint
    public init(position: MTPoint, velocity: MTPoint = MTPoint(x: 0, y: 0)) {
        self.position = position
        self.velocity = velocity
    }
}

public enum TouchPhase: Int32, Sendable, Equatable {
    case notTracking = 0
    case startInRange = 1
    case hoverInRange = 2
    case makeTouch = 3
    case touching = 4
    case breakTouch = 5
    case lingerInRange = 6
    case outOfRange = 7
}

public struct SyntheticTouch: Sendable, Equatable {
    public var id: Int32
    public var position: MTPoint
    public var velocity: MTPoint
    public var phase: TouchPhase
    public var timestamp: Double
    public var isBuiltIn: Bool
    public var majorRadius: Float
    public var minorRadius: Float

    public init(
        id: Int32 = 1,
        position: MTPoint,
        velocity: MTPoint = MTPoint(x: 0, y: 0),
        phase: TouchPhase = .touching,
        timestamp: Double = 0,
        isBuiltIn: Bool = true,
        majorRadius: Float = 5.0,
        minorRadius: Float = 5.0
    ) {
        self.id = id
        self.position = position
        self.velocity = velocity
        self.phase = phase
        self.timestamp = timestamp
        self.isBuiltIn = isBuiltIn
        self.majorRadius = majorRadius
        self.minorRadius = minorRadius
    }
}

// MARK: - Protocols

public protocol AudioControlling: Sendable {
    func getVolume() -> Float
    func setVolume(_ volume: Float)
    func isMuted() -> Bool
    func toggleMute() -> Bool
    func setVolumeListener(_ listener: @escaping @Sendable (Float, Bool) -> Void)
}

public protocol BrightnessControlling: Sendable {
    func getBrightness() -> Float
    func setBrightness(_ brightness: Float)
}

public protocol MediaControlling: Sendable {
    func playPause()
    func nextTrack()
    func previousTrack()
}

public protocol HUDManaging: AnyObject, Sendable {
    func showVolume(level: Float, isMuted: Bool)
    func showBrightness(level: Float)
    func showMedia(action: MediaAction)
    func dismissImmediately()
}

public protocol CursorControlling: AnyObject, Sendable {
    func freezeCursor(at point: CGPoint)
    func unfreezeCursor()
    var isFrozen: Bool { get }
}

public protocol HapticsPerforming: AnyObject, Sendable {
    func performTick()
    var tickCount: Int { get }
}

public protocol EdgeGestureEngineDelegate: AnyObject, Sendable {
    func handleGestureAction(_ action: EdgeGestureAction)
}

// MARK: - Mocks & Test Doubles

public final class MockAudioController: AudioControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var volume: Float = 0.5
    private var muted: Bool = false
    private var previousVolume: Float = 0.5
    private var listeners: [@Sendable (Float, Bool) -> Void] = []

    public var volumeHistory: [Float] = []
    public var muteHistory: [Bool] = []
    public var setVolumeCallCount: Int = 0
    public var toggleMuteCallCount: Int = 0

    public init(initialVolume: Float = 0.5, initialMuted: Bool = false) {
        self.volume = min(max(initialVolume, 0.0), 1.0)
        self.muted = initialMuted
        self.previousVolume = self.volume > 0 ? self.volume : 0.25
        self.volumeHistory.append(self.volume)
        self.muteHistory.append(self.muted)
    }

    public func getVolume() -> Float {
        lock.lock()
        defer { lock.unlock() }
        return volume
    }

    public func setVolume(_ newVolume: Float) {
        lock.lock()
        setVolumeCallCount += 1
        let clamped = min(max(newVolume, 0.0), 1.0)
        self.volume = clamped
        if clamped > 0 && muted {
            self.muted = false
            muteHistory.append(false)
        }
        if clamped > 0 {
            self.previousVolume = clamped
        }
        volumeHistory.append(clamped)
        let listenersCopy = self.listeners
        let currentMuted = self.muted
        lock.unlock()

        for l in listenersCopy {
            l(clamped, currentMuted)
        }
    }

    public func isMuted() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return muted
    }

    public func toggleMute() -> Bool {
        lock.lock()
        toggleMuteCallCount += 1
        if muted {
            // Unmute
            muted = false
            volume = previousVolume > 0 ? previousVolume : 0.25
        } else {
            // Mute
            previousVolume = volume > 0 ? volume : 0.25
            muted = true
            volume = 0.0
        }
        muteHistory.append(muted)
        volumeHistory.append(volume)
        let listenersCopy = self.listeners
        let currentVol = self.volume
        let currentMuted = self.muted
        lock.unlock()

        for l in listenersCopy {
            l(currentVol, currentMuted)
        }
        return currentMuted
    }

    public func setVolumeListener(_ listener: @escaping @Sendable (Float, Bool) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        listeners.append(listener)
    }

    public func simulateExternalHardwareChange(volume: Float, muted: Bool) {
        lock.lock()
        self.volume = min(max(volume, 0.0), 1.0)
        self.muted = muted
        volumeHistory.append(self.volume)
        muteHistory.append(self.muted)
        let listenersCopy = self.listeners
        let currentVol = self.volume
        let currentMuted = self.muted
        lock.unlock()

        for l in listenersCopy {
            l(currentVol, currentMuted)
        }
    }
}

public final class MockBrightnessManager: BrightnessControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var brightness: Float = 0.6
    public var brightnessHistory: [Float] = []
    public var setBrightnessCallCount: Int = 0
    public var activeDisplayID: UInt32 = 1

    public init(initialBrightness: Float = 0.6) {
        self.brightness = min(max(initialBrightness, 0.0), 1.0)
        self.brightnessHistory.append(self.brightness)
    }

    public func getBrightness() -> Float {
        lock.lock()
        defer { lock.unlock() }
        return brightness
    }

    public func setBrightness(_ newBrightness: Float) {
        lock.lock()
        defer { lock.unlock() }
        setBrightnessCallCount += 1
        let clamped = min(max(newBrightness, 0.0), 1.0)
        self.brightness = clamped
        brightnessHistory.append(clamped)
    }
}

public final class MockMediaManager: MediaControlling, @unchecked Sendable {
    private let lock = NSLock()
    public var recordedActions: [MediaAction] = []
    public var playPauseCount: Int = 0
    public var nextTrackCount: Int = 0
    public var prevTrackCount: Int = 0

    public init() {}

    public func playPause() {
        lock.lock()
        defer { lock.unlock() }
        playPauseCount += 1
        recordedActions.append(.playPause)
    }

    public func nextTrack() {
        lock.lock()
        defer { lock.unlock() }
        nextTrackCount += 1
        recordedActions.append(.nextTrack)
    }

    public func previousTrack() {
        lock.lock()
        defer { lock.unlock() }
        prevTrackCount += 1
        recordedActions.append(.previousTrack)
    }

    public func getActions() -> [MediaAction] {
        lock.lock()
        defer { lock.unlock() }
        return recordedActions
    }
}

public final class MockHUDManager: HUDManaging, @unchecked Sendable {
    private let lock = NSLock()
    public var currentType: HUDType?
    public var history: [HUDType] = []
    public var isDismissed: Bool = true
    public var dismissCount: Int = 0
    public var autoDismissScheduled: Bool = false
    public var autoDismissDelay: TimeInterval = 1.0

    public init() {}

    public func showVolume(level: Float, isMuted: Bool) {
        lock.lock()
        defer { lock.unlock() }
        let type = HUDType.volume(level: level, isMuted: isMuted)
        currentType = type
        history.append(type)
        isDismissed = false
        autoDismissScheduled = false
    }

    public func showBrightness(level: Float) {
        lock.lock()
        defer { lock.unlock() }
        let type = HUDType.brightness(level: level)
        currentType = type
        history.append(type)
        isDismissed = false
        autoDismissScheduled = false
    }

    public func showMedia(action: MediaAction) {
        lock.lock()
        defer { lock.unlock() }
        let type = HUDType.media(action: action)
        currentType = type
        history.append(type)
        isDismissed = false
        autoDismissScheduled = false
    }

    public func dismissImmediately() {
        lock.lock()
        defer { lock.unlock() }
        dismissCount += 1
        currentType = nil
        isDismissed = true
        autoDismissScheduled = false
    }

    public func scheduleAutoDismiss() {
        lock.lock()
        defer { lock.unlock() }
        autoDismissScheduled = true
    }

    public func triggerAutoDismiss() {
        lock.lock()
        defer { lock.unlock() }
        if autoDismissScheduled {
            dismissCount += 1
            currentType = nil
            isDismissed = true
            autoDismissScheduled = false
        }
    }
}

public final class MockCursorManager: CursorControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var frozen: Bool = false
    public var freezeCallCount: Int = 0
    public var unfreezeCallCount: Int = 0
    public var anchorPoint: CGPoint?

    public init() {}

    public var isFrozen: Bool {
        lock.lock()
        defer { lock.unlock() }
        return frozen
    }

    public func freezeCursor(at point: CGPoint) {
        lock.lock()
        defer { lock.unlock() }
        frozen = true
        freezeCallCount += 1
        anchorPoint = point
    }

    public func unfreezeCursor() {
        lock.lock()
        defer { lock.unlock() }
        frozen = false
        unfreezeCallCount += 1
        anchorPoint = nil
    }
}

public final class MockHapticsManager: HapticsPerforming, @unchecked Sendable {
    private let lock = NSLock()
    private var ticks: Int = 0

    public init() {}

    public var tickCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return ticks
    }

    public func performTick() {
        lock.lock()
        defer { lock.unlock() }
        ticks += 1
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        ticks = 0
    }
}

public final class MockStatusItemManager: @unchecked Sendable {
    private let lock = NSLock()
    public var state: StatusIconState = .idle
    public var stateHistory: [StatusIconState] = [.idle]

    public init() {}

    public func setState(_ newState: StatusIconState) {
        lock.lock()
        defer { lock.unlock() }
        state = newState
        stateHistory.append(newState)
    }

    public func getState() -> StatusIconState {
        lock.lock()
        defer { lock.unlock() }
        return state
    }
}

public final class MockAccessibilityManager: @unchecked Sendable {
    private let lock = NSLock()
    private var trusted: Bool = true
    public var promptCount: Int = 0
    public var lastDeepLinkURL: String?

    public init(initiallyTrusted: Bool = true) {
        self.trusted = initiallyTrusted
    }

    public func isTrusted() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return trusted
    }

    public func promptAccessibility() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        promptCount += 1
        return trusted
    }

    public func setTrusted(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        trusted = value
    }

    public func openSystemSettingsDeepLink() {
        lock.lock()
        defer { lock.unlock() }
        lastDeepLinkURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    }
}

// MARK: - Gesture Engine & Coordinate Normalizer

public enum GestureFSMState: Equatable, Sendable {
    case idle
    case candidate(edge: EdgeLocation, startPoint: MTPoint, startTime: Double)
    case sliding(edge: EdgeLocation, lastPoint: MTPoint, accumulatedDelta: Float, lastHapticStep: Float)
    case ending
}

public final class SimulatedGestureEngine: @unchecked Sendable {
    public weak var delegate: EdgeGestureEngineDelegate?

    public var bottomMargin: Float = 0.09
    public var cornerMargin: Float = 0.16
    public var deadzone: Float = 0.02
    public var doubleTapMaxInterval: Double = 0.30
    public var doubleTapMaxDistance: Float = 0.04

    private let lock = NSLock()
    public private(set) var currentState: GestureFSMState = .idle
    private var lastTapLocation: MTPoint?
    private var lastTapTime: Double = 0
    private var shiftOptionHeld: Bool = false
    private var activeGestureFingerCount: Int = 1

    public init() {}

    public func setShiftOptionModifier(_ held: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self.shiftOptionHeld = held
    }

    public func processFrame(
        touches: [SyntheticTouch],
        preferences: PreferencesSnapshot,
        cursorManager: CursorControlling?,
        hapticsManager: HapticsPerforming?
    ) {
        lock.lock()
        defer { lock.unlock() }

        // Filter touches: Magic mouse check
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

            let isAnyLifted = t1.phase == .breakTouch || t1.phase == .notTracking || t1.phase == .outOfRange
                || t2.phase == .breakTouch || t2.phase == .notTracking || t2.phase == .outOfRange
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
                        let precisionFactor: Float = (preferences.preciseSliding || shiftOptionHeld) ? 0.25 : 1.0
                        let scaledDy = dy * sensitivity * precisionFactor

                        let isRight = (candEdge == .right)
                        let isVolumeTarget = preferences.swapSides ? !isRight : isRight

                        if isVolumeTarget {
                            delegate?.handleGestureAction(.volumeDelta(scaledDy))
                        } else {
                            delegate?.handleGestureAction(.brightnessDelta(scaledDy))
                        }

                        var initialHapticStep: Float = 0
                        if preferences.enableHaptics {
                            let stepSize: Float = (preferences.preciseSliding || shiftOptionHeld) ? (1.0 / 64.0) : (1.0 / 16.0)
                            let currentStep = scaledDy / stepSize
                            let ticks = Int(abs(currentStep))
                            for _ in 0..<ticks {
                                hapticsManager?.performTick()
                            }
                            initialHapticStep = currentStep.rounded(.towardZero)
                        }

                        currentState = .sliding(edge: candEdge, lastPoint: centroid, accumulatedDelta: scaledDy, lastHapticStep: initialHapticStep)
                    } else if abs(dx) > deadzone * 2 {
                        currentState = .idle
                    }
                } else if candEdge == .bottom {
                    if abs(dx) > deadzone {
                        currentState = .sliding(edge: candEdge, lastPoint: centroid, accumulatedDelta: 0, lastHapticStep: 0)
                        cursorManager?.freezeCursor(at: CGPoint(x: CGFloat(centroid.x), y: CGFloat(centroid.y)))
                        delegate?.handleGestureAction(.gestureStarted(edge: candEdge))
                    } else if abs(dy) > deadzone * 2 {
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
                let precisionFactor: Float = (preferences.preciseSliding || shiftOptionHeld) ? 0.25 : 1.0

                if slideEdge == .left || slideEdge == .right {
                    let scaledDy = dy * sensitivity * precisionFactor
                    accumulated += scaledDy

                    let isRight = (slideEdge == .right)
                    let isVolumeTarget = preferences.swapSides ? !isRight : isRight

                    if isVolumeTarget {
                        delegate?.handleGestureAction(.volumeDelta(scaledDy))
                    } else {
                        delegate?.handleGestureAction(.brightnessDelta(scaledDy))
                    }

                    if preferences.enableHaptics {
                        let stepSize: Float = (preferences.preciseSliding || shiftOptionHeld) ? (1.0 / 64.0) : (1.0 / 16.0)
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
                    let scaledDx = dx * sensitivity * precisionFactor
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

        // Palm rejection: large contact patch
        if touch.majorRadius > 20.0 || touch.minorRadius > 20.0 {
            if case .sliding = currentState {
                endCurrentGesture(cursorManager: cursorManager)
            }
            currentState = .idle
            return
        }

        // If we were in a 2-finger slide and dropped to 1 finger, end gesture
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
                    if abs(dx) > deadzone * 2 || abs(dy) > deadzone * 2 {
                        currentState = .idle
                    }
                } else {
                    if edge == .bottom {
                        if abs(dx) > deadzone {
                            currentState = .sliding(edge: edge, lastPoint: p, accumulatedDelta: 0, lastHapticStep: 0)
                            cursorManager?.freezeCursor(at: CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)))
                            delegate?.handleGestureAction(.gestureStarted(edge: edge))
                        } else if abs(dy) > deadzone * 2 {
                            currentState = .idle
                        }
                    } else if edge == .left || edge == .right || edge == .topRightCorner {
                        let canSlide: Bool
                        let effectiveEdge: EdgeLocation
                        if edge == .topRightCorner {
                            effectiveEdge = .right
                            canSlide = (startPoint.y <= preferences.activeArea.maxY) || (preferences.activeArea == .entire)
                        } else {
                            effectiveEdge = edge
                            canSlide = true
                        }

                        if canSlide && abs(dy) > deadzone {
                            cursorManager?.freezeCursor(at: CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)))
                            delegate?.handleGestureAction(.gestureStarted(edge: effectiveEdge))

                            let sensitivity = Float(preferences.sensitivity)
                            let precisionFactor: Float = (preferences.preciseSliding || shiftOptionHeld) ? 0.25 : 1.0
                            let scaledDy = dy * sensitivity * precisionFactor

                            let isRight = (effectiveEdge == .right)
                            let isVolumeTarget = preferences.swapSides ? !isRight : isRight

                            if isVolumeTarget {
                                delegate?.handleGestureAction(.volumeDelta(scaledDy))
                            } else {
                                delegate?.handleGestureAction(.brightnessDelta(scaledDy))
                            }

                            var initialHapticStep: Float = 0
                            if preferences.enableHaptics {
                                let stepSize: Float = (preferences.preciseSliding || shiftOptionHeld) ? (1.0 / 64.0) : (1.0 / 16.0)
                                let currentStep = scaledDy / stepSize
                                let ticks = Int(abs(currentStep))
                                for _ in 0..<ticks {
                                    hapticsManager?.performTick()
                                }
                                initialHapticStep = currentStep.rounded(.towardZero)
                            }

                            currentState = .sliding(edge: effectiveEdge, lastPoint: p, accumulatedDelta: scaledDy, lastHapticStep: initialHapticStep)
                        } else if abs(dx) > deadzone * 2 {
                            currentState = .idle
                        }
                    }
                }

            case .sliding(let edge, let lastPoint, var accumulated, var lastHapticStep):
                let dy = p.y - lastPoint.y
                let dx = p.x - lastPoint.x

                // Check inward swipe cancellation
                if (edge == .left || edge == .right) && abs(dx) > deadzone * 3 {
                    endCurrentGesture(cursorManager: cursorManager)
                    return
                } else if edge == .bottom && abs(dy) > deadzone * 3 {
                    endCurrentGesture(cursorManager: cursorManager)
                    return
                }

                // Delta scaling with sensitivity and precise sliding
                let sensitivity = Float(preferences.sensitivity)
                let precisionFactor: Float = (preferences.preciseSliding || shiftOptionHeld) ? 0.25 : 1.0

                if edge == .bottom {
                    // Media swipe
                    let scaledDx = dx * sensitivity * precisionFactor
                    accumulated += scaledDx

                    // Action trigger threshold for track skip
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
                    let scaledDy = dy * sensitivity * precisionFactor
                    accumulated += scaledDy

                    // Determine target action based on side swapping
                    let isRight = (edge == .right)
                    let isVolumeTarget = preferences.swapSides ? !isRight : isRight

                    if isVolumeTarget {
                        delegate?.handleGestureAction(.volumeDelta(scaledDy))
                    } else {
                        delegate?.handleGestureAction(.brightnessDelta(scaledDy))
                    }

                    // Haptics calculation: discrete steps
                    if preferences.enableHaptics {
                        let stepSize: Float = (preferences.preciseSliding || shiftOptionHeld) ? (1.0 / 64.0) : (1.0 / 16.0)
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

    private func handleTouchLift(
        touch: SyntheticTouch,
        preferences: PreferencesSnapshot,
        cursorManager: CursorControlling?,
        hapticsManager: HapticsPerforming?
    ) {
        switch currentState {
        case .sliding:
            endCurrentGesture(cursorManager: cursorManager)

        case .candidate(let edge, let startPoint, let startTime):
            let dt = touch.timestamp - startTime
            let dist = distance(touch.position, startPoint)

            // Double tap check
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

    private func endCurrentGesture(cursorManager: CursorControlling?) {
        cursorManager?.unfreezeCursor()
        delegate?.handleGestureAction(.gestureEnded)
        currentState = .idle
        activeGestureFingerCount = 1
    }

    public func classifyEdge(point: MTPoint, edgeWidth: Float, activeArea: ActiveAreaZone) -> EdgeLocation {
        // Active area zone check on Y axis
        if point.y > activeArea.maxY {
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
                if centroid.y <= activeArea.maxY || activeArea == .entire || centroid.y >= (1.0 - cornerMargin) {
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
                if centroid.y <= activeArea.maxY || activeArea == .entire {
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

// MARK: - Central Simulated Edge App Coordinator

public final class SimulatedEdgeAppCoordinator: EdgeGestureEngineDelegate, @unchecked Sendable {
    public let audioController: AudioControlling
    public let brightnessManager: BrightnessControlling
    public let mediaManager: MediaControlling
    public let hudManager: HUDManaging
    public let cursorManager: CursorControlling
    public let hapticsManager: HapticsPerforming
    public let statusItemManager: MockStatusItemManager
    public let preferencesHolder: AtomicPreferencesHolder
    public let gestureEngine: SimulatedGestureEngine

    public private(set) var activeEdge: EdgeLocation = .none
    public private(set) var isGestureActive: Bool = false

    public init(
        audioController: AudioControlling,
        brightnessManager: BrightnessControlling,
        mediaManager: MediaControlling,
        hudManager: HUDManaging,
        cursorManager: CursorControlling,
        hapticsManager: HapticsPerforming,
        statusItemManager: MockStatusItemManager,
        preferencesHolder: AtomicPreferencesHolder,
        gestureEngine: SimulatedGestureEngine = SimulatedGestureEngine()
    ) {
        self.audioController = audioController
        self.brightnessManager = brightnessManager
        self.mediaManager = mediaManager
        self.hudManager = hudManager
        self.cursorManager = cursorManager
        self.hapticsManager = hapticsManager
        self.statusItemManager = statusItemManager
        self.preferencesHolder = preferencesHolder
        self.gestureEngine = gestureEngine

        self.gestureEngine.delegate = self

        // Wire audio listener to HUD
        self.audioController.setVolumeListener { [weak self] vol, muted in
            let prefs = self?.preferencesHolder.get() ?? .default
            if prefs.showOSD {
                self?.hudManager.showVolume(level: vol, isMuted: muted)
            }
        }
    }

    public func handleGestureAction(_ action: EdgeGestureAction) {
        let prefs = preferencesHolder.get()

        switch action {
        case .gestureStarted(let edge):
            activeEdge = edge
            isGestureActive = true
            statusItemManager.setState(.active)

        case .gestureEnded:
            activeEdge = .none
            isGestureActive = false
            statusItemManager.setState(.idle)
            if let mockHUD = hudManager as? MockHUDManager {
                mockHUD.scheduleAutoDismiss()
            }

        case .volumeDelta(let delta):
            let current = audioController.getVolume()
            let newVolume = min(max(current + delta, 0.0), 1.0)
            audioController.setVolume(newVolume)
            if prefs.showOSD {
                hudManager.showVolume(level: newVolume, isMuted: audioController.isMuted())
            }

        case .brightnessDelta(let delta):
            let current = brightnessManager.getBrightness()
            let newBrightness = min(max(current + delta, 0.0), 1.0)
            brightnessManager.setBrightness(newBrightness)
            if prefs.showOSD {
                hudManager.showBrightness(level: newBrightness)
            }

        case .quickMute:
            let isMuted = audioController.toggleMute()
            if prefs.showOSD {
                hudManager.showVolume(level: audioController.getVolume(), isMuted: isMuted)
            }
            if let mockHUD = hudManager as? MockHUDManager {
                mockHUD.scheduleAutoDismiss()
            }

        case .mediaPlayPause:
            mediaManager.playPause()
            if prefs.showOSD {
                hudManager.showMedia(action: .playPause)
            }
            if let mockHUD = hudManager as? MockHUDManager {
                mockHUD.scheduleAutoDismiss()
            }

        case .mediaNext:
            mediaManager.nextTrack()
            if prefs.showOSD {
                hudManager.showMedia(action: .nextTrack)
            }
            if let mockHUD = hudManager as? MockHUDManager {
                mockHUD.scheduleAutoDismiss()
            }

        case .mediaPrevious:
            mediaManager.previousTrack()
            if prefs.showOSD {
                hudManager.showMedia(action: .previousTrack)
            }
            if let mockHUD = hudManager as? MockHUDManager {
                mockHUD.scheduleAutoDismiss()
            }
        }
    }

    public func injectTouches(_ touches: [SyntheticTouch]) {
        let prefs = preferencesHolder.get()
        gestureEngine.processFrame(
            touches: touches,
            preferences: prefs,
            cursorManager: cursorManager,
            hapticsManager: hapticsManager
        )
    }
}

// MARK: - Master Test Harness Facade

public final class TestHarness {
    public let audio: MockAudioController
    public let brightness: MockBrightnessManager
    public let media: MockMediaManager
    public let hud: MockHUDManager
    public let cursor: MockCursorManager
    public let haptics: MockHapticsManager
    public let statusItem: MockStatusItemManager
    public let accessibility: MockAccessibilityManager
    public let prefsHolder: AtomicPreferencesHolder
    public let coordinator: SimulatedEdgeAppCoordinator

    public init(
        initialVolume: Float = 0.5,
        initialBrightness: Float = 0.6,
        preferences: PreferencesSnapshot = .default,
        initiallyTrustedAccessibility: Bool = true
    ) {
        self.audio = MockAudioController(initialVolume: initialVolume)
        self.brightness = MockBrightnessManager(initialBrightness: initialBrightness)
        self.media = MockMediaManager()
        self.hud = MockHUDManager()
        self.cursor = MockCursorManager()
        self.haptics = MockHapticsManager()
        self.statusItem = MockStatusItemManager()
        self.accessibility = MockAccessibilityManager(initiallyTrusted: initiallyTrustedAccessibility)
        self.prefsHolder = AtomicPreferencesHolder(snapshot: preferences)

        self.coordinator = SimulatedEdgeAppCoordinator(
            audioController: audio,
            brightnessManager: brightness,
            mediaManager: media,
            hudManager: hud,
            cursorManager: cursor,
            hapticsManager: haptics,
            statusItemManager: statusItem,
            preferencesHolder: prefsHolder
        )
    }

    // MARK: - Injection Utilities

    public func injectTouch(
        x: Float,
        y: Float,
        phase: TouchPhase = .touching,
        timestamp: Double = 0,
        isBuiltIn: Bool = true,
        majorRadius: Float = 5.0,
        minorRadius: Float = 5.0
    ) {
        let touch = SyntheticTouch(
            id: 1,
            position: MTPoint(x: x, y: y),
            phase: phase,
            timestamp: timestamp,
            isBuiltIn: isBuiltIn,
            majorRadius: majorRadius,
            minorRadius: minorRadius
        )
        coordinator.injectTouches([touch])
    }

    public func injectDrag(
        from: (Float, Float),
        to: (Float, Float),
        steps: Int = 10,
        startTime: Double = 100.0,
        duration: Double = 0.2
    ) {
        let dt = duration / Double(steps)
        let dx = (to.0 - from.0) / Float(steps)
        let dy = (to.1 - from.1) / Float(steps)

        // Make touch
        injectTouch(x: from.0, y: from.1, phase: .makeTouch, timestamp: startTime)

        // Steps
        for i in 1...steps {
            let cx = from.0 + dx * Float(i)
            let cy = from.1 + dy * Float(i)
            let ct = startTime + dt * Double(i)
            injectTouch(x: cx, y: cy, phase: .touching, timestamp: ct)
        }

        // Lift
        injectTouch(x: to.0, y: to.1, phase: .breakTouch, timestamp: startTime + duration + 0.01)
    }

    public func injectTap(at: (Float, Float), timestamp: Double = 100.0, duration: Double = 0.05) {
        injectTouch(x: at.0, y: at.1, phase: .makeTouch, timestamp: timestamp)
        injectTouch(x: at.0, y: at.1, phase: .touching, timestamp: timestamp + 0.01)
        injectTouch(x: at.0, y: at.1, phase: .breakTouch, timestamp: timestamp + duration)
    }

    public func injectDoubleTap(
        at: (Float, Float),
        interval: Double = 0.15,
        startTime: Double = 100.0,
        secondOffset: (Float, Float) = (0, 0)
    ) {
        // First tap
        injectTap(at: at, timestamp: startTime, duration: 0.04)

        // Second tap
        let secondX = at.0 + secondOffset.0
        let secondY = at.1 + secondOffset.1
        injectTap(at: (secondX, secondY), timestamp: startTime + interval, duration: 0.04)
    }

    // MARK: - Assertion Helpers

    public func assertVolume(
        _ expected: Float,
        accuracy: Float = 0.005,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let actual = audio.getVolume()
        #expect(abs(actual - expected) <= accuracy, "Volume scalar mismatch: expected \(expected), got \(actual)", sourceLocation: sourceLocation)
    }

    public func assertBrightness(
        _ expected: Float,
        accuracy: Float = 0.005,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let actual = brightness.getBrightness()
        #expect(abs(actual - expected) <= accuracy, "Brightness scalar mismatch: expected \(expected), got \(actual)", sourceLocation: sourceLocation)
    }

    public func assertMuted(
        _ expected: Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(audio.isMuted() == expected, "Mute state mismatch", sourceLocation: sourceLocation)
    }

    public func assertMediaActions(
        _ expected: [MediaAction],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(media.getActions() == expected, "Media action history mismatch", sourceLocation: sourceLocation)
    }

    public func assertCursorFrozen(
        _ expected: Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(cursor.isFrozen == expected, "Cursor freeze state mismatch", sourceLocation: sourceLocation)
    }

    public func assertHapticTicks(
        min: Int,
        max: Int? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let actual = haptics.tickCount
        if let max = max {
            #expect(actual >= min && actual <= max, "Haptic tick count \(actual) not in [\(min), \(max)]", sourceLocation: sourceLocation)
        } else {
            #expect(actual >= min, "Haptic tick count \(actual) < expected min \(min)", sourceLocation: sourceLocation)
        }
    }

    public func updatePreferences(_ modify: (inout PreferencesSnapshot) -> Void) {
        var current = prefsHolder.get()
        modify(&current)
        prefsHolder.set(current)
    }
}
