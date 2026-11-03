// Sources/Edge/Model/PreferencesSnapshot.swift
import Foundation

/// Active area restriction along the vertical trackpad edge.
///
/// Normalized coordinate system: origin (0.0, 0.0) is the bottom-left of the physical trackpad surface,
/// and (1.0, 1.0) is the top-right. Accidental activations are prevented by restricting active touch
/// candidate detection to the bottom portions of the trackpad.
public enum ActiveAreaZone: String, CaseIterable, Identifiable, Sendable, Codable, Equatable, Hashable {
    case entire = "entire"
    case bottomThreeQuarters = "bottomThreeQuarters"
    case bottomHalf = "bottomHalf"
    case bottomQuarter = "bottomQuarter"

    public var id: String { rawValue }

    /// Localized, user-facing descriptive label for settings pickers.
    public var title: String {
        switch self {
        case .entire:
            return "Entire Edge (100%)"
        case .bottomThreeQuarters:
            return "Bottom 3/4 (75%)"
        case .bottomHalf:
            return "Bottom Half (50%)"
        case .bottomQuarter:
            return "Bottom 1/4 (25%)"
        }
    }

    /// User-facing percentage string.
    public var percentageString: String {
        switch self {
        case .entire:
            return "100%"
        case .bottomThreeQuarters:
            return "75%"
        case .bottomHalf:
            return "50%"
        case .bottomQuarter:
            return "25%"
        }
    }

    /// Maximum normalized Y coordinate allowed for edge gesture candidate activation.
    /// In physical trackpad coordinates, y = 0.0 is bottom and y = 1.0 is top.
    public var maxY: Double {
        switch self {
        case .entire:
            return 1.0
        case .bottomThreeQuarters:
            return 0.75
        case .bottomHalf:
            return 0.50
        case .bottomQuarter:
            return 0.25
        }
    }

    /// Alias for maxY to maintain compatibility across components.
    public var maxNormalizedY: Double {
        return maxY
    }

    /// Evaluates whether a normalized vertical position falls within the active zone.
    /// - Parameter y: Normalized vertical position (0.0 = bottom edge, 1.0 = top edge).
    /// - Returns: `true` if the touch coordinate is inside the permitted active area.
    @inlinable
    public func contains(normalizedY y: Double) -> Bool {
        return y >= 0.0 && y <= maxY
    }
}

/// Immutable, thread-safe snapshot of user preferences for high-frequency gesture evaluation.
public struct PreferencesSnapshot: Sendable, Codable, Equatable {
    // Hardware boundary ranges
    public static let edgeWidthRange: ClosedRange<Double> = 0.03...0.20
    public static let defaultEdgeWidth: Double = 0.08

    public static let sensitivityRange: ClosedRange<Double> = 0.5...2.5
    public static let defaultSensitivity: Double = 1.0

    /// Master enable switch for edge gesture processing.
    public var isEnabled: Bool

    /// If true, swaps Volume to the Left edge and Brightness to the Right edge.
    /// Default (false): Volume on Right, Brightness on Left.
    public var swapSides: Bool

    /// Normalized margin width along left/right boundaries (0.03 to 0.20). Default: 0.08.
    public var edgeWidth: Double

    /// Gesture velocity multiplier (0.5 to 2.5). Default: 1.0.
    public var sensitivity: Double

    /// Vertical restriction zone for edge candidate activation.
    public var activeArea: ActiveAreaZone

    /// Inverts track change swipe direction on bottom media strip.
    public var reverseMediaSwipe: Bool

    /// Enables global quarter-step (1/64th) precision volume and brightness increments.
    public var preciseSliding: Bool

    /// Enables edge gesture detection on external Magic Mouse touch surfaces.
    public var enableMagicMouse: Bool

    /// Enables floating on-screen display (OSD HUD) feedback overlays during adjustments.
    public var showOSD: Bool

    /// Enables haptic feedback clicks during step transitions.
    public var enableHaptics: Bool

    /// Default configuration matching the project specification.
    public static let `default` = PreferencesSnapshot(
        isEnabled: true,
        swapSides: false,
        edgeWidth: defaultEdgeWidth,
        sensitivity: defaultSensitivity,
        activeArea: .entire,
        reverseMediaSwipe: false,
        preciseSliding: false,
        enableMagicMouse: false,
        showOSD: true,
        enableHaptics: true
    )

    /// Designated memberwise initializer with automated value clamping.
    public init(
        isEnabled: Bool = true,
        swapSides: Bool = false,
        edgeWidth: Double = defaultEdgeWidth,
        sensitivity: Double = defaultSensitivity,
        activeArea: ActiveAreaZone = .entire,
        reverseMediaSwipe: Bool = false,
        preciseSliding: Bool = false,
        enableMagicMouse: Bool = false,
        showOSD: Bool = true,
        enableHaptics: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.swapSides = swapSides
        self.edgeWidth = min(max(edgeWidth, Self.edgeWidthRange.lowerBound), Self.edgeWidthRange.upperBound)
        self.sensitivity = min(max(sensitivity, Self.sensitivityRange.lowerBound), Self.sensitivityRange.upperBound)
        self.activeArea = activeArea
        self.reverseMediaSwipe = reverseMediaSwipe
        self.preciseSliding = preciseSliding
        self.enableMagicMouse = enableMagicMouse
        self.showOSD = showOSD
        self.enableHaptics = enableHaptics
    }

    // MARK: - Compatibility Accessors

    /// Normalized edge width fraction alias for survey and UI interoperability.
    public var edgeWidthFraction: Double {
        get { edgeWidth }
        set { edgeWidth = min(max(newValue, Self.edgeWidthRange.lowerBound), Self.edgeWidthRange.upperBound) }
    }

    /// Sensitivity multiplier alias.
    public var sensitivityMultiplier: Double {
        get { sensitivity }
        set { sensitivity = min(max(newValue, Self.sensitivityRange.lowerBound), Self.sensitivityRange.upperBound) }
    }

    /// Magic mouse toggle alias.
    public var magicMouseEnabled: Bool {
        get { enableMagicMouse }
        set { enableMagicMouse = newValue }
    }

    /// Haptic feedback toggle alias.
    public var hapticFeedbackEnabled: Bool {
        get { enableHaptics }
        set { enableHaptics = newValue }
    }

    /// OSD HUD toggle alias.
    public var showOSDHUD: Bool {
        get { showOSD }
        set { showOSD = newValue }
    }

    // MARK: - Codable Custom Resilient Implementation

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case swapSides
        case edgeWidth
        case edgeWidthFraction
        case sensitivity
        case sensitivityMultiplier
        case activeArea
        case reverseMediaSwipe
        case preciseSliding
        case enableMagicMouse
        case magicMouseEnabled
        case showOSD
        case showOSDHUD
        case enableHaptics
        case hapticFeedbackEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.swapSides = try container.decodeIfPresent(Bool.self, forKey: .swapSides) ?? false

        let decodedWidth = try container.decodeIfPresent(Double.self, forKey: .edgeWidth)
            ?? container.decodeIfPresent(Double.self, forKey: .edgeWidthFraction)
            ?? Self.defaultEdgeWidth
        self.edgeWidth = min(max(decodedWidth, Self.edgeWidthRange.lowerBound), Self.edgeWidthRange.upperBound)

        let decodedSens = try container.decodeIfPresent(Double.self, forKey: .sensitivity)
            ?? container.decodeIfPresent(Double.self, forKey: .sensitivityMultiplier)
            ?? Self.defaultSensitivity
        self.sensitivity = min(max(decodedSens, Self.sensitivityRange.lowerBound), Self.sensitivityRange.upperBound)

        if let rawArea = try? container.decodeIfPresent(String.self, forKey: .activeArea) {
            self.activeArea = ActiveAreaZone(rawValue: rawArea) ?? .entire
        } else {
            self.activeArea = .entire
        }
        self.reverseMediaSwipe = try container.decodeIfPresent(Bool.self, forKey: .reverseMediaSwipe) ?? false
        self.preciseSliding = try container.decodeIfPresent(Bool.self, forKey: .preciseSliding) ?? false

        self.enableMagicMouse = try container.decodeIfPresent(Bool.self, forKey: .enableMagicMouse)
            ?? container.decodeIfPresent(Bool.self, forKey: .magicMouseEnabled)
            ?? false

        self.showOSD = try container.decodeIfPresent(Bool.self, forKey: .showOSD)
            ?? container.decodeIfPresent(Bool.self, forKey: .showOSDHUD)
            ?? true

        self.enableHaptics = try container.decodeIfPresent(Bool.self, forKey: .enableHaptics)
            ?? container.decodeIfPresent(Bool.self, forKey: .hapticFeedbackEnabled)
            ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(swapSides, forKey: .swapSides)
        try container.encode(edgeWidth, forKey: .edgeWidth)
        try container.encode(sensitivity, forKey: .sensitivity)
        try container.encode(activeArea, forKey: .activeArea)
        try container.encode(reverseMediaSwipe, forKey: .reverseMediaSwipe)
        try container.encode(preciseSliding, forKey: .preciseSliding)
        try container.encode(enableMagicMouse, forKey: .enableMagicMouse)
        try container.encode(showOSD, forKey: .showOSD)
        try container.encode(enableHaptics, forKey: .enableHaptics)
    }
}
