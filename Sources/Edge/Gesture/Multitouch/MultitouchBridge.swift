// Sources/Edge/Gesture/Multitouch/MultitouchBridge.swift
import Foundation
import CoreFoundation
import Darwin

// MARK: - Protocols & Delegate Definitions

/// Delegate protocol receiving raw multitouch contact frames.
public protocol MultitouchBridgeDelegate: AnyObject, Sendable {
    func multitouchBridge(
        _ bridge: any MultitouchBridging,
        didReceiveTouches touches: [MTTouch],
        deviceKind: MultitouchDeviceKind,
        isBuiltIn: Bool,
        timestamp: Double,
        frame: Int32
    )
}

/// Abstract interface for Multitouch bridge implementations, enabling test doubles and headless CI runners.
public protocol MultitouchBridging: AnyObject, Sendable {
    var isRunning: Bool { get }
    var detectedDevices: [MultitouchDeviceKind] { get }
    func start() throws
    func stop()
    func setDelegate(_ delegate: (any MultitouchBridgeDelegate)?)
    func simulateFrame(
        touches: [MTTouch],
        isBuiltIn: Bool,
        deviceKind: MultitouchDeviceKind,
        timestamp: Double,
        frame: Int32
    )
}

// MARK: - Error Types

public enum MultitouchBridgeError: Error, LocalizedError, Sendable {
    case frameworkNotFound(path: String, message: String)
    case symbolNotFound(symbol: String)
    case deviceStartFailed(code: Int32)

    public var errorDescription: String? {
        switch self {
        case .frameworkNotFound(let path, let message):
            return "MultitouchSupport framework not found at '\(path)': \(message)"
        case .symbolNotFound(let symbol):
            return "Required dynamic symbol '\(symbol)' not found in MultitouchSupport"
        case .deviceStartFailed(let code):
            return "Failed to start multitouch device (error code: \(code))"
        }
    }
}

// MARK: - Low-Level C ABI Bindings

public typealias MTDeviceRef = OpaquePointer

private typealias MTDeviceCreateListFunc = @convention(c) () -> Unmanaged<CFMutableArray>?
private typealias MTDeviceIsBuiltInFunc = @convention(c) (MTDeviceRef) -> Bool
private typealias MTDeviceIsRunningFunc = @convention(c) (MTDeviceRef) -> Bool
private typealias MTDeviceGetDriverTypeFunc = @convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>) -> Int32
private typealias MTDeviceGetDeviceIDFunc = @convention(c) (MTDeviceRef, UnsafeMutablePointer<UInt64>) -> Int32
private typealias MTDeviceGetSensorSurfaceDimensionsFunc = @convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
private typealias MTDeviceStartFunc = @convention(c) (MTDeviceRef, Int32) -> Int32
private typealias MTDeviceStopFunc = @convention(c) (MTDeviceRef) -> Int32

private typealias MTContactCallbackFunc = @convention(c) (
    MTDeviceRef,
    UnsafeMutableRawPointer?,
    Int,
    Double,
    Int,
    UnsafeMutableRawPointer?
) -> Void

private typealias MTRegisterContactFrameCallbackWithRefconFunc = @convention(c) (
    MTDeviceRef,
    MTContactCallbackFunc,
    UnsafeMutableRawPointer?
) -> Void

private typealias MTUnregisterContactFrameCallbackFunc = @convention(c) (
    MTDeviceRef,
    MTContactCallbackFunc
) -> Void

// MARK: - Global C Callback Trampoline & Registry

private final class MultitouchRegistry {
    static let lock = NSLock()
    static weak var activeBridge: MultitouchBridge?
}

/// C callback trampoline registered with MultitouchSupport.
/// Resolves the bridge instance from the safe active bridge registry
/// and converts the C memory buffer into safe Sendable Swift structs.
private let globalMultitouchCallback: MTContactCallbackFunc = { device, dataPtr, count, timestamp, frame, refcon in
    MultitouchRegistry.lock.lock()
    guard let bridge = MultitouchRegistry.activeBridge, bridge.isRunning else {
        MultitouchRegistry.lock.unlock()
        return
    }
    MultitouchRegistry.lock.unlock()

    var touches: [MTTouch] = []
    if let dataPtr = dataPtr, count > 0 {
        let typedPtr = dataPtr.assumingMemoryBound(to: MTTouch.self)
        let buffer = UnsafeBufferPointer(start: typedPtr, count: count)
        touches = Array(buffer)
    }

    bridge.handleHardwareFrame(
        device: device,
        touches: touches,
        timestamp: timestamp,
        frame: Int32(frame & 0x7FFFFFFF)
    )
}

// MARK: - MultitouchBridge Implementation

/// Production Multitouch bridge connecting macOS MultitouchSupport.framework to the Edge Gesture Engine.
/// Thread-safe via internal synchronization (`NSLock`) and fully Sendable compliant.
public final class MultitouchBridge: MultitouchBridging, @unchecked Sendable {
    public static let defaultFrameworkPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"

    private struct DeviceRecord {
        let ref: MTDeviceRef
        let isBuiltIn: Bool
        let kind: MultitouchDeviceKind
        let deviceID: UInt64
        var isRegistered: Bool
        var isRunning: Bool
    }

    private let lock = NSLock()
    private var dylibHandle: UnsafeMutableRawPointer?
    private var cfDeviceList: CFMutableArray?
    private var activeDevices: [DeviceRecord] = []
    private var _isRunning: Bool = false
    private weak var delegate: (any MultitouchBridgeDelegate)?

    // Function pointers resolved via dlsym
    private var fnCreateList: MTDeviceCreateListFunc?
    private var fnIsBuiltIn: MTDeviceIsBuiltInFunc?
    private var fnGetDriverType: MTDeviceGetDriverTypeFunc?
    private var fnGetDeviceID: MTDeviceGetDeviceIDFunc?
    private var fnGetDimensions: MTDeviceGetSensorSurfaceDimensionsFunc?
    private var fnStart: MTDeviceStartFunc?
    private var fnStop: MTDeviceStopFunc?
    private var fnRegisterCallback: MTRegisterContactFrameCallbackWithRefconFunc?
    private var fnUnregisterCallback: MTUnregisterContactFrameCallbackFunc?

    /// Optional thread-safe preferences holder to query live settings (e.g., enableMagicMouse).
    public var preferencesHolder: AtomicPreferencesHolder?

    /// Explicit fallback flag if preferencesHolder is not injected.
    public var enableMagicMouse: Bool = false

    public init(preferencesHolder: AtomicPreferencesHolder? = nil) {
        self.preferencesHolder = preferencesHolder
        loadFramework()
    }

    deinit {
        stop()
        if let handle = dylibHandle {
            dlclose(handle)
        }
    }

    // MARK: - State Inspection

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isRunning
    }

    public var detectedDevices: [MultitouchDeviceKind] {
        lock.lock()
        defer { lock.unlock() }
        return activeDevices.map { $0.kind }
    }

    public func setDelegate(_ delegate: (any MultitouchBridgeDelegate)?) {
        lock.lock()
        defer { lock.unlock() }
        self.delegate = delegate
    }

    // MARK: - Dynamic Loading

    private func loadFramework() {
        guard let handle = dlopen(Self.defaultFrameworkPath, RTLD_NOW) else {
            return
        }
        self.dylibHandle = handle

        if let p = dlsym(handle, "MTDeviceCreateList") {
            fnCreateList = unsafeBitCast(p, to: MTDeviceCreateListFunc.self)
        }
        if let p = dlsym(handle, "MTDeviceIsBuiltIn") {
            fnIsBuiltIn = unsafeBitCast(p, to: MTDeviceIsBuiltInFunc.self)
        }
        if let p = dlsym(handle, "MTDeviceGetDriverType") {
            fnGetDriverType = unsafeBitCast(p, to: MTDeviceGetDriverTypeFunc.self)
        }
        if let p = dlsym(handle, "MTDeviceGetDeviceID") {
            fnGetDeviceID = unsafeBitCast(p, to: MTDeviceGetDeviceIDFunc.self)
        }
        if let p = dlsym(handle, "MTDeviceGetSensorSurfaceDimensions") {
            fnGetDimensions = unsafeBitCast(p, to: MTDeviceGetSensorSurfaceDimensionsFunc.self)
        }
        if let p = dlsym(handle, "MTDeviceStart") {
            fnStart = unsafeBitCast(p, to: MTDeviceStartFunc.self)
        }
        if let p = dlsym(handle, "MTDeviceStop") {
            fnStop = unsafeBitCast(p, to: MTDeviceStopFunc.self)
        }
        if let p = dlsym(handle, "MTRegisterContactFrameCallbackWithRefcon") {
            fnRegisterCallback = unsafeBitCast(p, to: MTRegisterContactFrameCallbackWithRefconFunc.self)
        }
        if let p = dlsym(handle, "MTUnregisterContactFrameCallback") {
            fnUnregisterCallback = unsafeBitCast(p, to: MTUnregisterContactFrameCallbackFunc.self)
        }
    }

    // MARK: - Lifecycle Management

    public func start() throws {
        try start(enableHardware: true)
    }

    public func start(enableHardware: Bool) throws {
        lock.lock()
        defer { lock.unlock() }

        guard !_isRunning else { return }

        guard enableHardware else {
            self._isRunning = true
            return
        }

        // If running in headless CI without private framework access, allow simulation mode
        guard let createList = fnCreateList,
              let registerCallback = fnRegisterCallback,
              let startDevice = fnStart else {
            _isRunning = true
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var discovered: [DeviceRecord] = []

        if let unmanagedList = createList() {
            let cfList = unmanagedList.takeRetainedValue()
            self.cfDeviceList = cfList
            let count = CFArrayGetCount(cfList)

            for i in 0..<count {
                guard let devVal = CFArrayGetValueAtIndex(cfList, i) else { continue }
                let dev = MTDeviceRef(devVal)
                let builtIn = fnIsBuiltIn?(dev) ?? false

                var driverType: Int32 = 0
                _ = fnGetDriverType?(dev, &driverType)

                var w: Int32 = 0, h: Int32 = 0
                _ = fnGetDimensions?(dev, &w, &h)

                var devID: UInt64 = 0
                _ = fnGetDeviceID?(dev, &devID)

                // Classify device kind
                let kind: MultitouchDeviceKind
                if builtIn {
                    kind = .builtInTrackpad
                } else if driverType <= 2 || (w > 0 && h > 0 && Float(w) / Float(h) < 0.8) {
                    kind = .magicMouse
                } else {
                    kind = .magicTrackpad
                }

                // Register frame callback with refcon pointing to self
                registerCallback(dev, globalMultitouchCallback, refcon)

                // Start hardware stream
                let status = startDevice(dev, 0)
                let running = (status == 0)

                discovered.append(DeviceRecord(
                    ref: dev,
                    isBuiltIn: builtIn,
                    kind: kind,
                    deviceID: devID,
                    isRegistered: true,
                    isRunning: running
                ))
            }
        }

        self.activeDevices = discovered
        self._isRunning = true

        MultitouchRegistry.lock.lock()
        MultitouchRegistry.activeBridge = self
        MultitouchRegistry.lock.unlock()
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        guard _isRunning else { return }
        _isRunning = false

        MultitouchRegistry.lock.lock()
        if MultitouchRegistry.activeBridge === self {
            MultitouchRegistry.activeBridge = nil
        }
        MultitouchRegistry.lock.unlock()

        for dev in activeDevices {
            if dev.isRunning {
                _ = fnStop?(dev.ref)
            }
            if dev.isRegistered {
                fnUnregisterCallback?(dev.ref, globalMultitouchCallback)
            }
        }
        activeDevices.removeAll()
        self.cfDeviceList = nil
    }

    // MARK: - Internal Frame Dispatching

    fileprivate func handleHardwareFrame(
        device: MTDeviceRef,
        touches: [MTTouch],
        timestamp: Double,
        frame: Int32
    ) {
        lock.lock()
        guard _isRunning else {
            lock.unlock()
            return
        }

        let record = activeDevices.first(where: { $0.ref == device })
        let kind = record?.kind ?? .builtInTrackpad
        let isBuiltIn = record?.isBuiltIn ?? true

        // Magic mouse filtering check
        if kind == .magicMouse {
            let allowMouse = preferencesHolder?.get().enableMagicMouse ?? enableMagicMouse
            if !allowMouse {
                lock.unlock()
                return
            }
        }

        let currentDelegate = delegate
        let builtIn = isBuiltIn
        lock.unlock()

        currentDelegate?.multitouchBridge(
            self,
            didReceiveTouches: touches,
            deviceKind: kind,
            isBuiltIn: builtIn,
            timestamp: timestamp,
            frame: frame
        )
    }

    // MARK: - Synthetic Injection for Testing

    public func simulateFrame(
        touches: [MTTouch],
        isBuiltIn: Bool = true,
        deviceKind: MultitouchDeviceKind = .builtInTrackpad,
        timestamp: Double = ProcessInfo.processInfo.systemUptime,
        frame: Int32 = 0
    ) {
        lock.lock()
        guard _isRunning else {
            lock.unlock()
            return
        }

        if deviceKind == .magicMouse {
            let allowMouse = preferencesHolder?.get().enableMagicMouse ?? enableMagicMouse
            if !allowMouse {
                lock.unlock()
                return
            }
        }

        let currentDelegate = delegate
        lock.unlock()

        currentDelegate?.multitouchBridge(
            self,
            didReceiveTouches: touches,
            deviceKind: deviceKind,
            isBuiltIn: isBuiltIn,
            timestamp: timestamp,
            frame: frame
        )
    }
}

// MARK: - MockMultitouchBridge for Opaque-Box E2E Tests

/// Pure mock implementation for unit testing and CI test harnesses.
public final class MockMultitouchBridge: MultitouchBridging, @unchecked Sendable {
    private let lock = NSLock()
    private var _isRunning: Bool = false
    private weak var delegate: (any MultitouchBridgeDelegate)?

    public var startCallCount: Int = 0
    public var stopCallCount: Int = 0
    public var injectedFrames: [MultitouchFrame] = []
    public var mockDevices: [MultitouchDeviceKind] = [.builtInTrackpad]

    public init(initiallyRunning: Bool = false) {
        self._isRunning = initiallyRunning
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isRunning
    }

    public var detectedDevices: [MultitouchDeviceKind] {
        lock.lock()
        defer { lock.unlock() }
        return mockDevices
    }

    public func setDelegate(_ delegate: (any MultitouchBridgeDelegate)?) {
        lock.lock()
        defer { lock.unlock() }
        self.delegate = delegate
    }

    public func start() throws {
        lock.lock()
        defer { lock.unlock() }
        startCallCount += 1
        _isRunning = true
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        stopCallCount += 1
        _isRunning = false
    }

    public func simulateFrame(
        touches: [MTTouch],
        isBuiltIn: Bool = true,
        deviceKind: MultitouchDeviceKind = .builtInTrackpad,
        timestamp: Double = ProcessInfo.processInfo.systemUptime,
        frame: Int32 = 0
    ) {
        lock.lock()
        guard _isRunning else {
            lock.unlock()
            return
        }
        let frameObj = MultitouchFrame(
            isBuiltIn: isBuiltIn,
            deviceKind: deviceKind,
            frame: frame,
            timestamp: timestamp,
            touches: touches
        )
        injectedFrames.append(frameObj)
        let currentDelegate = delegate
        lock.unlock()

        currentDelegate?.multitouchBridge(
            self,
            didReceiveTouches: touches,
            deviceKind: deviceKind,
            isBuiltIn: isBuiltIn,
            timestamp: timestamp,
            frame: frame
        )
    }
}
