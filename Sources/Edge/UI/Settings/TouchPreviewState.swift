// Sources/Edge/UI/Settings/TouchPreviewState.swift
import Foundation
import SwiftUI

/// Detected edge zone classification for touch feedback
public enum TouchDetectedZone: String, Sendable, Equatable {
    case leftEdge = "Left Edge"
    case rightEdge = "Right Edge"
    case bottomStrip = "Bottom Media Strip"
    case topRightCorner = "Top-Right Mute Corner"
    case centerSurface = "Center Surface (Inactive)"
}

/// Represents a single normalized touch contact point
public struct NormalizedContact: Identifiable, Sendable, Equatable {
    public let id: Int
    public let x: Double // 0.0 (left) to 1.0 (right)
    public let y: Double // 0.0 (bottom) to 1.0 (top)
    public let detectedZone: TouchDetectedZone
    public let isEdgeActive: Bool
    
    public init(id: Int, x: Double, y: Double, detectedZone: TouchDetectedZone, isEdgeActive: Bool) {
        self.id = id
        self.x = x
        self.y = y
        self.detectedZone = detectedZone
        self.isEdgeActive = isEdgeActive
    }
}

/// Observable state holding real-time touch contacts for the Settings preview.
/// Only receives updates when isActive == true (Settings window visible).
@MainActor
public final class TouchPreviewState: ObservableObject {
    public static let shared = TouchPreviewState()
    
    /// Controls whether background touch events are forwarded to this preview
    @Published public var isActive: Bool = false
    
    /// Current active touch contacts
    @Published public var contacts: [NormalizedContact] = []
    
    /// Latest gesture or active zone description
    @Published public var activeFeedbackText: String = "Ready — Touch edges to test"
    
    public init() {}
    
    public func clearTouches() {
        contacts.removeAll()
        activeFeedbackText = "Ready — Touch edges to test"
    }
    
    /// Called by EdgeGestureEngine or MultitouchBridge when touches are received
    public func updateHardwareTouches(
        points: [(id: Int, x: Double, y: Double)],
        edgeWidth: Double,
        activeArea: ActiveAreaZone,
        swapSides: Bool
    ) {
        guard isActive else { return }
        
        let maxY = activeArea.maxNormalizedY
        var updatedContacts: [NormalizedContact] = []
        var activeZoneText: String = "Touching Surface"
        
        for pt in points {
            let x = pt.x
            let y = pt.y
            let inActiveHeight = y <= maxY
            
            let zone: TouchDetectedZone
            let isActiveEdge: Bool
            
            // Check top-right corner
            if x >= (1.0 - edgeWidth) && y >= 0.85 {
                zone = .topRightCorner
                isActiveEdge = true
                activeZoneText = "Top-Right Corner: Quick Mute 🔇"
            } else if x <= edgeWidth {
                zone = .leftEdge
                isActiveEdge = inActiveHeight
                let role = swapSides ? "Volume 🔊" : "Brightness ☀️"
                activeZoneText = inActiveHeight ? "Left Edge: \(role)" : "Left Edge (Palm Guard Masked)"
            } else if x >= (1.0 - edgeWidth) {
                zone = .rightEdge
                isActiveEdge = inActiveHeight
                let role = swapSides ? "Brightness ☀️" : "Volume 🔊"
                activeZoneText = inActiveHeight ? "Right Edge: \(role)" : "Right Edge (Palm Guard Masked)"
            } else if y <= 0.10 {
                zone = .bottomStrip
                isActiveEdge = true
                activeZoneText = "Bottom Edge: Media Strip ⏯"
            } else {
                zone = .centerSurface
                isActiveEdge = false
            }
            
            updatedContacts.append(
                NormalizedContact(
                    id: pt.id,
                    x: x,
                    y: y,
                    detectedZone: zone,
                    isEdgeActive: isActiveEdge
                )
            )
        }
        
        self.contacts = updatedContacts
        if !updatedContacts.isEmpty {
            self.activeFeedbackText = activeZoneText
        } else {
            self.activeFeedbackText = "Ready — Touch edges to test"
        }
    }
    
    /// Simulates a touch contact from within the SettingsView interactive drag canvas
    public func simulateTouch(
        x: Double,
        y: Double,
        edgeWidth: Double,
        activeArea: ActiveAreaZone,
        swapSides: Bool
    ) {
        updateHardwareTouches(
            points: [(id: 999, x: x, y: y)],
            edgeWidth: edgeWidth,
            activeArea: activeArea,
            swapSides: swapSides
        )
    }
}
