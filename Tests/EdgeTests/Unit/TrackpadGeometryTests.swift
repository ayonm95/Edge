// Tests/EdgeTests/Unit/TrackpadGeometryTests.swift
import Testing
import CoreGraphics
@testable import Edge

@Suite("Trackpad Geometry Unit Tests")
struct TrackpadGeometryTests {
    
    @Test("Coordinate conversion hardware to view")
    func coordinateConversionHardwareToView() {
        let canvasWidth: CGFloat = 400
        let canvasHeight: CGFloat = 200
        
        // 1. Bottom-Left corner (0.0, 0.0) -> SwiftUI View (0.0, 200.0)
        let hwBL = (x: 0.0, y: 0.0)
        let viewBL_X = CGFloat(hwBL.x) * canvasWidth
        let viewBL_Y = CGFloat(1.0 - hwBL.y) * canvasHeight
        #expect(abs(viewBL_X - 0.0) < 0.001)
        #expect(abs(viewBL_Y - 200.0) < 0.001)
        
        // 2. Top-Right corner (1.0, 1.0) -> SwiftUI View (400.0, 0.0)
        let hwTR = (x: 1.0, y: 1.0)
        let viewTR_X = CGFloat(hwTR.x) * canvasWidth
        let viewTR_Y = CGFloat(1.0 - hwTR.y) * canvasHeight
        #expect(abs(viewTR_X - 400.0) < 0.001)
        #expect(abs(viewTR_Y - 0.0) < 0.001)
        
        // 3. Center (0.5, 0.5) -> SwiftUI View (200.0, 100.0)
        let hwCenter = (x: 0.5, y: 0.5)
        let viewC_X = CGFloat(hwCenter.x) * canvasWidth
        let viewC_Y = CGFloat(1.0 - hwCenter.y) * canvasHeight
        #expect(abs(viewC_X - 200.0) < 0.001)
        #expect(abs(viewC_Y - 100.0) < 0.001)
    }
    
    @Test("Active area zone cutoffs")
    func activeAreaZoneCutoffs() {
        #expect(Edge.ActiveAreaZone.entire.maxNormalizedY == 1.0)
        #expect(Edge.ActiveAreaZone.bottomThreeQuarters.maxNormalizedY == 0.75)
        #expect(Edge.ActiveAreaZone.bottomHalf.maxNormalizedY == 0.50)
        #expect(Edge.ActiveAreaZone.bottomQuarter.maxNormalizedY == 0.25)
    }
    
    @Test("Touch preview state zone detection")
    @MainActor
    func touchPreviewStateZoneDetection() {
        let state = TouchPreviewState.shared
        state.isActive = true
        
        // Test Left Edge Active
        state.updateHardwareTouches(
            points: [(id: 1, x: 0.04, y: 0.30)],
            edgeWidth: 0.08,
            activeArea: .bottomHalf,
            swapSides: false
        )
        #expect(state.contacts.first?.detectedZone == .leftEdge)
        #expect(state.contacts.first?.isEdgeActive == true)
        
        // Test Left Edge Masked (Palm Guard active in top half)
        state.updateHardwareTouches(
            points: [(id: 1, x: 0.04, y: 0.70)],
            edgeWidth: 0.08,
            activeArea: .bottomHalf,
            swapSides: false
        )
        #expect(state.contacts.first?.detectedZone == .leftEdge)
        #expect(state.contacts.first?.isEdgeActive == false)
        
        // Test Top-Right Corner Mute
        state.updateHardwareTouches(
            points: [(id: 2, x: 0.95, y: 0.90)],
            edgeWidth: 0.08,
            activeArea: .entire,
            swapSides: false
        )
        #expect(state.contacts.first?.detectedZone == .topRightCorner)
        #expect(state.contacts.first?.isEdgeActive == true)
    }
}
