// Sources/Edge/Hardware/BrightnessManager.swift
import Foundation
import CoreGraphics
import AppKit

/// Protocol defining the display brightness control interface.
public protocol BrightnessControlling: Sendable {
    /// Returns current display brightness scalar in the range [0.0, 1.0].
    func getBrightness() -> Float

    /// Sets display brightness scalar clamped to [0.0, 1.0].
    func setBrightness(_ brightness: Float)
}

/// Hardware display brightness manager using dynamic linking into macOS DisplayServices and CoreDisplay.
///
/// Features:
/// - Dynamic runtime symbol resolution via `dlopen`/`dlsym` for `DisplayServices.framework`.
/// - Secondary fallback to `CoreDisplay.framework` (`CoreDisplay_Display_GetUserBrightness`).
/// - Multi-display awareness: resolves active screen and `CGDirectDisplayID` matching cursor location.
/// - Clamped [0.0, 1.0] range enforcement with robust `.isFinite` NaN / Inf sanitization.
/// - Internal caching ensuring reliable operation in testing, headless CI, or unsupported display environments.
public final class BrightnessManager: BrightnessControlling, @unchecked Sendable {
    public static let shared = BrightnessManager()

    // Function pointer signatures for DisplayServices.framework
    private typealias DisplayServicesGetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias DisplayServicesSetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32

    // Function pointer signatures for CoreDisplay.framework
    private typealias CoreDisplayGetUserBrightnessFunc = @convention(c) (CGDirectDisplayID) -> Double
    private typealias CoreDisplaySetUserBrightnessFunc = @convention(c) (CGDirectDisplayID, Double) -> Void

    private var dsGetBrightness: DisplayServicesGetBrightnessFunc?
    private var dsSetBrightness: DisplayServicesSetBrightnessFunc?
    private var cdGetUserBrightness: CoreDisplayGetUserBrightnessFunc?
    private var cdSetUserBrightness: CoreDisplaySetUserBrightnessFunc?

    private let lock = NSLock()
    private var cachedBrightness: Float = 0.6

    public init() {
        loadSymbols()
    }

    private func loadSymbols() {
        // 1. Load private DisplayServices.framework
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) {
            if let getSym = dlsym(handle, "DisplayServicesGetBrightness") {
                dsGetBrightness = unsafeBitCast(getSym, to: DisplayServicesGetBrightnessFunc.self)
            }
            if let setSym = dlsym(handle, "DisplayServicesSetBrightness") {
                dsSetBrightness = unsafeBitCast(setSym, to: DisplayServicesSetBrightnessFunc.self)
            }
        }

        // 2. Load CoreDisplay.framework as secondary fallback
        if let cdHandle = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_NOW) {
            if let getSym = dlsym(cdHandle, "CoreDisplay_Display_GetUserBrightness") {
                cdGetUserBrightness = unsafeBitCast(getSym, to: CoreDisplayGetUserBrightnessFunc.self)
            }
            if let setSym = dlsym(cdHandle, "CoreDisplay_Display_SetUserBrightness") {
                cdSetUserBrightness = unsafeBitCast(setSym, to: CoreDisplaySetUserBrightnessFunc.self)
            }
        }
    }

    // MARK: - Display Targeting

    /// Resolves the CGDirectDisplayID containing the user's active cursor or the main screen.
    public func targetDisplayID() -> CGDirectDisplayID {
        let mouseLoc = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) {
            if let screenNum = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                return screenNum
            }
        }
        if let mainScreen = NSScreen.main,
           let screenNum = mainScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            return screenNum
        }
        return CGMainDisplayID()
    }

    // MARK: - BrightnessControlling Protocol Implementation

    public func getBrightness() -> Float {
        return getBrightness(displayID: targetDisplayID())
    }

    public func setBrightness(_ brightness: Float) {
        setBrightness(brightness, displayID: targetDisplayID())
    }

    // MARK: - Display-Specific Accessors

    /// Returns brightness scalar for a specific display ID.
    public func getBrightness(displayID: CGDirectDisplayID) -> Float {
        lock.lock()
        defer { lock.unlock() }

        // 1. Try DisplayServices
        if let getFunc = dsGetBrightness {
            var val: Float = 0.0
            if getFunc(displayID, &val) == 0 {
                guard val.isFinite else { return cachedBrightness }
                let clamped = min(max(val, 0.0), 1.0)
                cachedBrightness = clamped
                return clamped
            }
        }

        // 2. Fallback to CoreDisplay
        if let getFunc = cdGetUserBrightness {
            let rawVal = getFunc(displayID)
            let val = Float(rawVal)
            guard val.isFinite else { return cachedBrightness }
            let clamped = min(max(val, 0.0), 1.0)
            cachedBrightness = clamped
            return clamped
        }

        return cachedBrightness
    }

    /// Sets brightness scalar for a specific display ID.
    @discardableResult
    public func setBrightness(_ value: Float, displayID: CGDirectDisplayID) -> Bool {
        guard value.isFinite else { return false }
        let clamped = min(max(value, 0.0), 1.0)
        lock.lock()
        cachedBrightness = clamped
        lock.unlock()

        var success = false

        // 1. Try DisplayServices
        if let setFunc = dsSetBrightness {
            let res = setFunc(displayID, clamped)
            if res == 0 {
                success = true
            }
        }

        // 2. Fallback to CoreDisplay
        if !success, let setFunc = cdSetUserBrightness {
            setFunc(displayID, Double(clamped))
            success = true
        }

        return success
    }

    /// Adjusts brightness by a relative delta.
    @discardableResult
    public func adjustBrightness(delta: Float, displayID: CGDirectDisplayID? = nil) -> Float {
        guard delta.isFinite else { return getBrightness(displayID: displayID ?? targetDisplayID()) }
        let targetID = displayID ?? targetDisplayID()
        let current = getBrightness(displayID: targetID)
        let newBrightness = min(max(current + delta, 0.0), 1.0)
        setBrightness(newBrightness, displayID: targetID)
        return newBrightness
    }

    /// Steps brightness up or down in discrete increments (standard 1/16th or fine 1/64th).
    @discardableResult
    public func stepBrightness(up: Bool, fine: Bool = false, displayID: CGDirectDisplayID? = nil) -> Float {
        let step: Float = fine ? (1.0 / 64.0) : (1.0 / 16.0)
        return adjustBrightness(delta: up ? step : -step, displayID: displayID)
    }
}
