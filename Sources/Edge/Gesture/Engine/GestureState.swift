// Sources/Edge/Gesture/Engine/GestureState.swift
import Foundation

/// 4-State Gesture Finite State Machine enum.
/// Tracks the lifecycle of edge interactions from touch contact to gesture completion.
public enum GestureState: Equatable, Sendable {
    /// Idle state: no active touches being tracked within edge zones.
    case idle

    /// Candidate state: touch registered within an edge boundary, evaluating whether it is
    /// a tap, a slide (exceeding deadzone), or accidental/palm contact.
    case candidate(edge: EdgeLocation, startPoint: MTPoint, startTime: Double)

    /// Sliding state: active drag in progress along the edge axis. Cursor is frozen,
    /// haptic ticks are discretized, and value changes are dispatched.
    case sliding(edge: EdgeLocation, lastPoint: MTPoint, accumulatedDelta: Float, lastHapticStep: Float)

    /// Ending state: touch has lifted or broken; teardown actions are executed
    /// (unfreezing cursor, firing gestureEnded, resetting to idle).
    case ending
}

/// Typealias for backward compatibility with test harnesses and E2E suites.
public typealias GestureFSMState = GestureState
