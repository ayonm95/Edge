// Sources/Edge/Gesture/Cursor/CursorManager.swift
import Foundation
import CoreGraphics
import AppKit
import os.log

/// Protocol defining cursor freeze, unfreeze, and coordinate anchoring.
public protocol CursorControlling: AnyObject, Sendable {
    func freezeCursor(at point: CGPoint)
    func unfreezeCursor()
    var isFrozen: Bool { get }
}

/// Triple-layer cursor freeze controller for macOS edge gesture sliding.
///
/// Implements a 3-layer architecture to ensure cursor invisibility and positional locking
/// while the user is actively sliding their finger on trackpad edges:
///
/// 1. **Layer 1: Global Visibility**:
///    `CGDisplayHideCursor(kCGNullDirectDisplay)` / `CGDisplayShowCursor(kCGNullDirectDisplay)`
///    Hides the cursor across all displays. Uses an internal boolean gate to strictly balance
///    WindowServer's internal hide reference count and prevent cursor loss.
///
/// 2. **Layer 2: Positional Warping**:
///    `CGWarpMouseCursorPosition(anchorPoint)`
///    Pins the hardware cursor coordinates to the recorded gesture anchor point, preventing
///    unintended mouse drift and accidental hover states in background applications.
///
/// 3. **Layer 3: HID Event Suppression**:
///    `CGEventTap` (.cghidEventTap / .headInsertEventTap)
///    Intercepts and drops `.mouseMoved`, `.leftMouseDragged`, `.rightMouseDragged`,
///    `.otherMouseDragged`, and `.scrollWheel` events during active sliding.
///    Gracefully degrades if Accessibility permissions are missing or in unit tests.
///
/// Thread Safety:
private final class CursorTapRegistry {
    static let lock = NSLock()
    static weak var activeManager: CursorManager?
}

/// Fully thread-safe across concurrent 120Hz callback threads and `@MainActor` via an internal `NSLock`.
public final class CursorManager: CursorControlling, @unchecked Sendable {
    /// Shared singleton instance.
    public static let shared = CursorManager(isShared: true, installEventTapOnFreeze: true)

    private let lock = NSLock()
    private var _isFrozen: Bool = false
    private var _anchorPoint: CGPoint?
    private var _screenWarpPoint: CGPoint?
    private var _freezeCount: Int = 0
    private var _unfreezeCount: Int = 0

    private var _eventTapPort: CFMachPort?
    private var _runLoopSource: CFRunLoopSource?
    private var terminationObserver: (any NSObjectProtocol)?
    private var _tapAttempted: Bool = false

    /// Controls whether CGEventTap is automatically installed on freeze.
    /// Enabled for shared singleton, disabled by default for unit test instances to avoid WindowServer contention.
    public var installEventTapOnFreeze: Bool

    private let logger = Logger(subsystem: "com.edge.slider", category: "CursorManager")

    // MARK: - Initialization & Teardown

    public init(isShared: Bool = false, installEventTapOnFreeze: Bool = false) {
        self.installEventTapOnFreeze = isShared || installEventTapOnFreeze
        if isShared {
            self.terminationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleAppWillTerminate()
            }
        }
    }

    deinit {
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        tearDown()
    }

    private func handleAppWillTerminate() {
        unfreezeCursor()
        tearDownEventTap()
    }

    // MARK: - CursorControlling Protocol

    /// Indicates whether the cursor is currently frozen.
    public var isFrozen: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isFrozen
    }

    /// The recorded anchor point where the gesture began, in caller coordinates.
    public var anchorPoint: CGPoint? {
        lock.lock()
        defer { lock.unlock() }
        return _anchorPoint
    }

    /// Cumulative count of freeze invocations.
    public var freezeCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _freezeCount
    }

    /// Cumulative count of unfreeze invocations.
    public var unfreezeCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _unfreezeCount
    }

    /// Indicates whether the low-level CGEventTap is currently installed and active.
    public var isEventTapActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _eventTapPort != nil
    }

    /// Freezes the cursor at the specified coordinates.
    ///
    /// Idempotent: Calling `freezeCursor` when already frozen updates the anchor
    /// point and warps the cursor, but does NOT double-increment WindowServer's hide count.
    ///
    /// - Parameter point: The anchor point to freeze at. Supports normalized (0...1) coordinates
    ///   or screen coordinates. If normalized coordinates are passed, the current system
    ///   cursor position is used for hardware warping to prevent jumping to (0,0).
    public func freezeCursor(at point: CGPoint) {
        lock.lock()

        if _isFrozen {
            _anchorPoint = point
            if point.x > 1.0 || point.y > 1.0 {
                _screenWarpPoint = point
            }
            let warpLoc = _screenWarpPoint ?? point
            lock.unlock()
            CGWarpMouseCursorPosition(warpLoc)
            return
        }

        _isFrozen = true
        _freezeCount += 1
        _anchorPoint = point

        let screenPoint: CGPoint
        if point.x > 1.0 || point.y > 1.0 {
            screenPoint = point
        } else {
            screenPoint = CGEvent(source: nil)?.location ?? point
        }
        _screenWarpPoint = screenPoint

        ensureEventTapInstalledLocked()
        lock.unlock()

        // Layer 1: Hide cursor globally across all displays
        CGDisplayHideCursor(kCGNullDirectDisplay)

        // Layer 2: Warp to anchor point
        CGWarpMouseCursorPosition(screenPoint)
    }

    /// Unfreezes the cursor, restoring global visibility and position.
    ///
    /// Idempotent: Calling `unfreezeCursor` when not frozen is a safe no-op and
    /// will not decrement WindowServer's hide counter below zero.
    public func unfreezeCursor() {
        lock.lock()
        guard _isFrozen else {
            lock.unlock()
            return
        }

        _isFrozen = false
        _unfreezeCount += 1
        let warpLoc = _screenWarpPoint
        _anchorPoint = nil
        _screenWarpPoint = nil
        lock.unlock()

        // Layer 2: Final warp back to anchor location
        if let warpLoc = warpLoc {
            CGWarpMouseCursorPosition(warpLoc)
        }

        // Layer 1: Show cursor globally across all displays
        CGDisplayShowCursor(kCGNullDirectDisplay)
    }

    /// Re-warps the cursor to the current anchor point during active sliding.
    public func warpToAnchor() {
        lock.lock()
        guard _isFrozen, let warpLoc = _screenWarpPoint else {
            lock.unlock()
            return
        }
        lock.unlock()
        CGWarpMouseCursorPosition(warpLoc)
    }

    /// Resets all counters and ensures the cursor is unhidden (primarily for test harness cleanup).
    public func reset() {
        lock.lock()
        let wasFrozen = _isFrozen
        _isFrozen = false
        _anchorPoint = nil
        _screenWarpPoint = nil
        _freezeCount = 0
        _unfreezeCount = 0
        lock.unlock()

        if wasFrozen {
            CGDisplayShowCursor(kCGNullDirectDisplay)
        }
    }

    /// Full teardown of event tap and cursor state.
    public func tearDown() {
        unfreezeCursor()
        tearDownEventTap()
    }

    // MARK: - Layer 3: Low-Level Event Tap Management

    /// Installs the event tap if accessibility permissions allow it.
    public func setupEventTap() {
        lock.lock()
        defer { lock.unlock() }
        installEventTapOnFreeze = true
        ensureEventTapInstalledLocked()
    }

    private func ensureEventTapInstalledLocked() {
        guard installEventTapOnFreeze else { return }
        guard _eventTapPort == nil else { return }

        let eventsOfInterest: CGEventMask = (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.rightMouseDragged.rawValue)
            | (1 << CGEventType.otherMouseDragged.rawValue)
            | (1 << CGEventType.scrollWheel.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            CursorTapRegistry.lock.lock()
            guard let manager = CursorTapRegistry.activeManager else {
                CursorTapRegistry.lock.unlock()
                return Unmanaged.passUnretained(event)
            }
            CursorTapRegistry.lock.unlock()
            return manager.handleEventTap(proxy: proxy, type: type, event: event)
        }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventsOfInterest,
            callback: callback,
            userInfo: refcon
        ) else {
            if !_tapAttempted {
                _tapAttempted = true
                logger.info("CGEventTap unavailable (requires Accessibility permission or running in test runner). Operating with dual-layer Hide + Warp.")
            }
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            logger.error("Failed to create CFRunLoopSource for CGEventTap.")
            CFMachPortInvalidate(tap)
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        CursorTapRegistry.lock.lock()
        CursorTapRegistry.activeManager = self
        CursorTapRegistry.lock.unlock()

        self._eventTapPort = tap
        self._runLoopSource = source
        logger.info("Triple-layer CGEventTap installed and active at .headInsertEventTap.")
    }

    private func handleEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            lock.lock()
            if let tap = _eventTapPort {
                CGEvent.tapEnable(tap: tap, enable: true)
                logger.debug("CGEventTap re-enabled after system timeout.")
            }
            lock.unlock()
            return Unmanaged.passUnretained(event)
        }

        lock.lock()
        let frozen = _isFrozen
        lock.unlock()

        if frozen {
            switch type {
            case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel:
                // Suppress event from reaching system or underlying applications
                return nil
            default:
                break
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func tearDownEventTap() {
        lock.lock()
        defer { lock.unlock() }

        CursorTapRegistry.lock.lock()
        if CursorTapRegistry.activeManager === self {
            CursorTapRegistry.activeManager = nil
        }
        CursorTapRegistry.lock.unlock()

        if let tap = _eventTapPort {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            _eventTapPort = nil
        }

        if let source = _runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            _runLoopSource = nil
        }
        _tapAttempted = false
    }
}
