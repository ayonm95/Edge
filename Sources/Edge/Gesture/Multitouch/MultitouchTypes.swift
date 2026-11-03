// Sources/Edge/Gesture/Multitouch/MultitouchTypes.swift
import Foundation

// MARK: - Point & Vector Structs

/// 2D normalized contact coordinates [0.0 ... 1.0].
/// Origin (0.0, 0.0) is the bottom-left of the physical trackpad surface,
/// matching Apple MultitouchSupport Cartesian coordinates.
public struct MTPoint: Sendable, Equatable, Codable {
    public var x: Float
    public var y: Float

    public static let zero = MTPoint(x: 0, y: 0)

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

/// Vector containing normalized position and instantaneous velocity.
public struct MTVector: Sendable, Equatable, Codable {
    public var position: MTPoint
    public var velocity: MTPoint

    public static let zero = MTVector(position: .zero, velocity: .zero)

    public init(position: MTPoint, velocity: MTPoint = .zero) {
        self.position = position
        self.velocity = velocity
    }
}

// MARK: - Touch Phase & State Enum

/// Lifecycle state enum for Multitouch contact paths.
/// Matches Apple MultitouchSupport.framework MTTouchState values.
public enum TouchPhase: Int32, Sendable, Equatable, CaseIterable, Codable {
    case notTracking = 0
    case startInRange = 1
    case hoverInRange = 2
    case makeTouch = 3
    case touching = 4
    case breakTouch = 5
    case lingerInRange = 6
    case outOfRange = 7

    /// Indicates physical surface contact is active.
    @inlinable
    public var isActiveContact: Bool {
        self == .makeTouch || self == .touching
    }

    /// Indicates finger was lifted or tracking ended.
    @inlinable
    public var isLifted: Bool {
        self == .breakTouch || self == .notTracking || self == .outOfRange
    }
}

/// Compatibility alias matching Apple C enum naming convention.
public typealias MTTouchState = TouchPhase

// MARK: - 96-Byte C Struct Layout for MTTouch

/// Exact 96-byte C struct mapping the raw contact structure emitted by MultitouchSupport.framework.
/// Memory layout verified on macOS ARM64 and x86_64:
/// - Size: 96 bytes
/// - Stride: 96 bytes
/// - Alignment: 8 bytes (due to timestamp Double alignment at offset 8)
public struct MTTouch: Sendable, Equatable {
    public var frame: Int32               // Offset 0: Frame sequence number (4 bytes)
    // Offset 4: 4 bytes padding for 8-byte alignment of timestamp
    public var timestamp: Double          // Offset 8: Hardware timestamp in seconds (8 bytes)
    public var pathIndex: Int32          // Offset 16: Hardware transducer index (4 bytes)
    public var state: Int32              // Offset 20: TouchPhase raw value (4 bytes)
    public var fingerID: Int32           // Offset 24: Unique persistent finger ID (4 bytes)
    public var handID: Int32             // Offset 28: Hand identifier (typically 1) (4 bytes)
    public var normalizedVector: MTVector// Offset 32: Position (x,y) & velocity (16 bytes)
    public var density: Float            // Offset 48: Contact area density (4 bytes)
    public var error: Float              // Offset 52: Contact error / reserved (4 bytes)
    public var majorAxis: Float          // Offset 56: Major axis of contact ellipse in mm (4 bytes)
    public var minorAxis: Float          // Offset 60: Minor axis of contact ellipse in mm (4 bytes)
    public var angle: Float              // Offset 64: Orientation angle in radians (4 bytes)
    public var eccen: Float              // Offset 68: Contact ellipse eccentricity (4 bytes)
    public var zTotal: Float             // Offset 72: Total capacitance / pressure metric (4 bytes)
    public var zPressure: Float          // Offset 76: Physical force / force-touch pressure (4 bytes)
    public var reserved1: Float          // Offset 80: Reserved / absolute vector x (4 bytes)
    public var reserved2: Float          // Offset 84: Reserved / absolute vector y (4 bytes)
    public var reserved3: Float          // Offset 88: Reserved / absolute velocity x (4 bytes)
    public var reserved4: Float          // Offset 92: Reserved / absolute velocity y (4 bytes)

    public init(
        frame: Int32 = 0,
        timestamp: Double = 0,
        pathIndex: Int32 = 0,
        state: Int32 = TouchPhase.touching.rawValue,
        fingerID: Int32 = 1,
        handID: Int32 = 1,
        normalizedVector: MTVector = .zero,
        density: Float = 0,
        error: Float = 0,
        majorAxis: Float = 5.0,
        minorAxis: Float = 5.0,
        angle: Float = 0,
        eccen: Float = 0,
        zTotal: Float = 0.5,
        zPressure: Float = 0.5,
        reserved1: Float = 0,
        reserved2: Float = 0,
        reserved3: Float = 0,
        reserved4: Float = 0
    ) {
        self.frame = frame
        self.timestamp = timestamp
        self.pathIndex = pathIndex
        self.state = state
        self.fingerID = fingerID
        self.handID = handID
        self.normalizedVector = normalizedVector
        self.density = density
        self.error = error
        self.majorAxis = majorAxis
        self.minorAxis = minorAxis
        self.angle = angle
        self.eccen = eccen
        self.zTotal = zTotal
        self.zPressure = zPressure
        self.reserved1 = reserved1
        self.reserved2 = reserved2
        self.reserved3 = reserved3
        self.reserved4 = reserved4
    }

    // MARK: - Convenience Accessors

    /// Strongly-typed phase enum resolved from raw state integer.
    @inlinable
    public var phase: TouchPhase {
        get { TouchPhase(rawValue: state) ?? .notTracking }
        set { state = newValue.rawValue }
    }

    /// Normalized position on the trackpad surface [0.0 ... 1.0].
    @inlinable
    public var position: MTPoint {
        get { normalizedVector.position }
        set { normalizedVector.position = newValue }
    }

    /// Instantaneous normalized tracking velocity.
    @inlinable
    public var velocity: MTPoint {
        get { normalizedVector.velocity }
        set { normalizedVector.velocity = newValue }
    }

    /// Alias for density matching alternate C headers.
    @inlinable
    public var zDensity: Float {
        get { density }
        set { density = newValue }
    }

    /// Major radius alias for contact ellipse major axis.
    @inlinable
    public var majorRadius: Float {
        get { majorAxis }
        set { majorAxis = newValue }
    }

    /// Minor radius alias for contact ellipse minor axis.
    @inlinable
    public var minorRadius: Float {
        get { minorAxis }
        set { minorAxis = newValue }
    }

    /// Synthesizes a touch contact for testing or simulation.
    public static func makeSynthetic(
        fingerID: Int32 = 1,
        x: Float,
        y: Float,
        phase: TouchPhase = .touching,
        timestamp: Double = 0,
        majorAxis: Float = 5.0,
        minorAxis: Float = 5.0,
        zTotal: Float = 0.5
    ) -> MTTouch {
        MTTouch(
            timestamp: timestamp,
            state: phase.rawValue,
            fingerID: fingerID,
            normalizedVector: MTVector(position: MTPoint(x: x, y: y)),
            majorAxis: majorAxis,
            minorAxis: minorAxis,
            zTotal: zTotal
        )
    }
}

// MARK: - Synthetic Touch Container for Simulation

/// High-level synthetic touch representation used for testing and simulation injection.
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

    /// Converts this synthetic touch to an ABI-compatible 96-byte MTTouch struct.
    public func toMTTouch() -> MTTouch {
        MTTouch(
            timestamp: timestamp,
            state: phase.rawValue,
            fingerID: id,
            normalizedVector: MTVector(position: position, velocity: velocity),
            majorAxis: majorRadius,
            minorAxis: minorRadius
        )
    }

    /// Creates a SyntheticTouch from an MTTouch struct.
    public init(from touch: MTTouch, isBuiltIn: Bool = true) {
        self.id = touch.fingerID
        self.position = touch.position
        self.velocity = touch.velocity
        self.phase = touch.phase
        self.timestamp = touch.timestamp
        self.isBuiltIn = isBuiltIn
        self.majorRadius = touch.majorAxis
        self.minorRadius = touch.minorAxis
    }
}

// MARK: - Device Classification

/// Hardware classification for multitouch input surfaces.
public enum MultitouchDeviceKind: String, Sendable, Codable, Equatable {
    case builtInTrackpad = "Built-in Trackpad"
    case magicTrackpad = "Magic Trackpad"
    case magicMouse = "Magic Mouse"
    case unknown = "Unknown Multitouch Device"
}

// MARK: - Safe Frame Container

/// Immutable, Sendable frame container encapsulating contacts from a single hardware polling cycle.
public struct MultitouchFrame: Sendable, Equatable {
    public let deviceID: UInt64
    public let isBuiltIn: Bool
    public let deviceKind: MultitouchDeviceKind
    public let frame: Int32
    public let timestamp: Double
    public let touches: [MTTouch]

    public init(
        deviceID: UInt64 = 0,
        isBuiltIn: Bool = true,
        deviceKind: MultitouchDeviceKind = .builtInTrackpad,
        frame: Int32 = 0,
        timestamp: Double = 0,
        touches: [MTTouch]
    ) {
        self.deviceID = deviceID
        self.isBuiltIn = isBuiltIn
        self.deviceKind = deviceKind
        self.frame = frame
        self.timestamp = timestamp
        self.touches = touches
    }
}
