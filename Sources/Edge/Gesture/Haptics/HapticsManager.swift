// Sources/Edge/Gesture/Haptics/HapticsManager.swift
import Foundation
import AppKit
import QuartzCore
import os.log

/// Protocol defining discrete haptic tick feedback.
public protocol HapticsPerforming: AnyObject, Sendable {
    func performTick()
    var tickCount: Int { get }
}

/// Thread-safe haptic feedback performer for edge gesture quantization.
///
/// Dispatches discrete tactile ticks via `NSHapticFeedbackManager.defaultPerformer`
/// when the user scrubs across volume or brightness step boundaries.
///
/// Features:
/// - **Rate Limiting**: Throttles hardware impulses to a minimum interval (`minTickInterval`,
///   default 25ms) to prevent physical Taptic Engine motor saturation and "mushy" buzzing
///   during 120Hz rapid gestures.
/// - **Testability**: Maintains a thread-safe `tickCount` that records all logical step crossings
///   for synthetic test assertion, with a `reset()` method for test harness reuse.
/// - **Hardware Resilience**: Safely no-ops on desktop Macs (Mac mini, Mac Studio, Mac Pro)
///   without trackpad hardware, preventing any runtime exceptions or crashes.
public final class HapticsManager: HapticsPerforming, @unchecked Sendable {
    /// Shared singleton instance.
    public static let shared = HapticsManager()

    private let lock = NSLock()
    private var _tickCount: Int = 0
    private var _hardwareTickCount: Int = 0
    private var _lastTickTime: CFTimeInterval = 0

    /// Minimum time interval (in seconds) between physical hardware haptic impulses.
    ///
    /// Default: 0.025 seconds (25ms), allowing up to 40 crisp ticks per second.
    /// Can be configured to 0.0 in unit tests for 1:1 hardware dispatch validation.
    public var minTickInterval: TimeInterval

    private let performer: any NSHapticFeedbackPerformer
    private let logger = Logger(subsystem: "com.edge.slider", category: "HapticsManager")

    // MARK: - Initialization

    /// Initializes a new HapticsManager instance.
    /// - Parameters:
    ///   - minInterval: Minimum interval between physical haptic pulses (default: 0.025s).
    ///   - performer: The haptic performer to use (defaults to `NSHapticFeedbackManager.defaultPerformer`).
    public init(
        minInterval: TimeInterval = 0.025,
        performer: any NSHapticFeedbackPerformer = NSHapticFeedbackManager.defaultPerformer
    ) {
        self.minTickInterval = minInterval
        self.performer = performer
    }

    // MARK: - HapticsPerforming Protocol

    /// The cumulative count of logical haptic ticks requested.
    ///
    /// Increments on every `performTick()` call to support deterministic assertions
    /// in unit and E2E test suites regardless of test execution speed.
    public var tickCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _tickCount
    }

    /// The cumulative count of physical haptic impulses actually dispatched to the hardware.
    public var hardwareTickCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _hardwareTickCount
    }

    /// Triggers a discrete haptic tick using the standard `.generic` pattern.
    ///
    /// Thread-safe: Safe to invoke concurrently from high-frequency gesture processing
    /// threads or `@MainActor`.
    public func performTick() {
        performTick(pattern: .generic, performanceTime: .default)
    }

    /// Triggers a haptic tick with a custom feedback pattern and performance timing.
    ///
    /// - Parameters:
    ///   - pattern: AppKit feedback pattern (e.g. `.generic`, `.alignment`, `.levelChange`).
    ///   - performanceTime: When the feedback should occur (e.g. `.default`, `.now`, `.drawCompleted`).
    public func performTick(
        pattern: NSHapticFeedbackManager.FeedbackPattern = .generic,
        performanceTime: NSHapticFeedbackManager.PerformanceTime = .default
    ) {
        lock.lock()
        _tickCount += 1

        let now = CACurrentMediaTime()
        let elapsed = now - _lastTickTime

        guard elapsed >= minTickInterval else {
            lock.unlock()
            // Rate-limited: suppresses hardware saturation during high-frequency scrub
            return
        }

        _lastTickTime = now
        _hardwareTickCount += 1
        lock.unlock()

        // Dispatch to hardware performer (safe across all Mac hardware)
        performer.perform(pattern, performanceTime: performanceTime)
    }

    /// Resets all tick counters and timer state (for test harness synchronization).
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        _tickCount = 0
        _hardwareTickCount = 0
        _lastTickTime = 0
    }
}
