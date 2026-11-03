// Sources/Edge/UI/Settings/TrackpadPreviewView.swift
import SwiftUI

/// Interactive visual representation of the trackpad surface.
/// Shows dynamic edge widths, active area palm-guard masking, and live touch pucks.
public struct TrackpadPreviewView: View {
    let edgeWidth: Double
    let activeArea: ActiveAreaZone
    let swapSides: Bool
    let reverseMediaSwipe: Bool
    
    @ObservedObject private var touchState = TouchPreviewState.shared
    
    public init(
        edgeWidth: Double,
        activeArea: ActiveAreaZone,
        swapSides: Bool,
        reverseMediaSwipe: Bool
    ) {
        self.edgeWidth = edgeWidth
        self.activeArea = activeArea
        self.swapSides = swapSides
        self.reverseMediaSwipe = reverseMediaSwipe
    }
    
    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let edgeW = max(w * CGFloat(edgeWidth), 16)
            let maxY = CGFloat(activeArea.maxNormalizedY)
            let activeTopY = h * (1.0 - maxY) // SwiftUI view Y coordinate
            
            ZStack {
                // Trackpad Base Enclosure
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1.5)
                    )
                
                // Palm-Guard Inactive Mask (Upper Left & Right when restricted)
                if activeArea != .entire {
                    // Left Inactive Region
                    Path { p in
                        p.addRect(CGRect(x: 0, y: 0, width: edgeW, height: activeTopY))
                    }
                    .fill(Color.secondary.opacity(0.12))
                    .overlay(
                        VStack {
                            Image(systemName: "hand.raised.slash.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Palm Guard")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: edgeW, height: activeTopY),
                        alignment: .top
                    )
                    
                    // Right Inactive Region
                    Path { p in
                        p.addRect(CGRect(x: w - edgeW, y: 0, width: edgeW, height: activeTopY))
                    }
                    .fill(Color.secondary.opacity(0.12))
                    .overlay(
                        VStack {
                            Image(systemName: "hand.raised.slash.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Palm Guard")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: edgeW, height: activeTopY),
                        alignment: .top
                    )
                    
                    // Active Boundary Dashed Divider
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: activeTopY))
                        p.addLine(to: CGPoint(x: edgeW, y: activeTopY))
                        p.move(to: CGPoint(x: w - edgeW, y: activeTopY))
                        p.addLine(to: CGPoint(x: w, y: activeTopY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundColor(Color.secondary.opacity(0.5))
                }
                
                // Left Active Edge (Brightness or Volume)
                let leftColor = swapSides ? Color.blue : Color.orange
                let leftSymbol = swapSides ? "speaker.wave.2.fill" : "sun.max.fill"
                let leftTitle = swapSides ? "Volume" : "Brightness"
                
                Path { p in
                    p.addRect(CGRect(x: 0, y: activeTopY, width: edgeW, height: h - activeTopY))
                }
                .fill(leftColor.opacity(0.28))
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: leftSymbol)
                            .font(.system(size: 14))
                            .foregroundColor(leftColor)
                        Text(leftTitle)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(leftColor)
                    }
                    .frame(width: edgeW, height: h - activeTopY),
                    alignment: .center
                )
                
                // Right Active Edge (Volume or Brightness)
                let rightColor = swapSides ? Color.orange : Color.blue
                let rightSymbol = swapSides ? "sun.max.fill" : "speaker.wave.2.fill"
                let rightTitle = swapSides ? "Brightness" : "Volume"
                
                Path { p in
                    p.addRect(CGRect(x: w - edgeW, y: activeTopY, width: edgeW, height: h - activeTopY))
                }
                .fill(rightColor.opacity(0.28))
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: rightSymbol)
                            .font(.system(size: 14))
                            .foregroundColor(rightColor)
                        Text(rightTitle)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(rightColor)
                    }
                    .frame(width: edgeW, height: h - activeTopY),
                    alignment: .center
                )
                
                // Top-Right Quick Mute Corner Indicator
                let cornerW = max(edgeW, 28)
                let cornerH: CGFloat = 26
                Path { p in
                    p.addRoundedRect(
                        in: CGRect(x: w - cornerW, y: 0, width: cornerW, height: cornerH),
                        cornerSize: CGSize(width: 4, height: 4)
                    )
                }
                .fill(Color.red.opacity(0.25))
                .overlay(
                    VStack(spacing: 1) {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                        Text("Mute")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .frame(width: cornerW, height: cornerH),
                    alignment: .center
                )
                
                // Bottom Edge Media Strip
                let mediaStripHeight: CGFloat = 22
                Path { p in
                    p.addRect(CGRect(
                        x: edgeW,
                        y: h - mediaStripHeight,
                        width: w - (edgeW * 2),
                        height: mediaStripHeight
                    ))
                }
                .fill(Color.purple.opacity(0.25))
                .overlay(
                    HStack(spacing: 14) {
                        Image(systemName: reverseMediaSwipe ? "forward.fill" : "backward.fill")
                        Image(systemName: "playpause.fill")
                        Image(systemName: reverseMediaSwipe ? "backward.fill" : "forward.fill")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.purple),
                    alignment: .center
                )
                
                // Surface Center Watermark & Status Readout
                VStack(spacing: 6) {
                    Text("TRACKPAD SURFACE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    // Live Action Feedback Badge
                    Text(touchState.activeFeedbackText)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                        .cornerRadius(6)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                }
                
                // Live Touch Pucks
                ForEach(touchState.contacts) { contact in
                    let puckX = CGFloat(contact.x) * w
                    let puckY = CGFloat(1.0 - contact.y) * h // Invert hardware Y to SwiftUI Y
                    
                    TouchPuckView(contact: contact)
                        .position(x: puckX, y: puckY)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
            // In-Window Interactive Drag Simulator
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let normX = Double(min(max(value.location.x / w, 0.0), 1.0))
                        let normY = Double(min(max(1.0 - (value.location.y / h), 0.0), 1.0))
                        
                        touchState.simulateTouch(
                            x: normX,
                            y: normY,
                            edgeWidth: edgeWidth,
                            activeArea: activeArea,
                            swapSides: swapSides
                        )
                    }
                    .onEnded { _ in
                        touchState.clearTouches()
                    }
            )
        }
    }
}

/// Animated glowing puck rendering raw contact points
public struct TouchPuckView: View {
    public let contact: NormalizedContact
    
    public init(contact: NormalizedContact) {
        self.contact = contact
    }
    
    public var puckColor: Color {
        switch contact.detectedZone {
        case .leftEdge:
            return contact.isEdgeActive ? .orange : .gray
        case .rightEdge:
            return contact.isEdgeActive ? .blue : .gray
        case .bottomStrip:
            return .purple
        case .topRightCorner:
            return .red
        case .centerSurface:
            return .accentColor
        }
    }
    
    public var body: some View {
        ZStack {
            // Pulsing Outer Halo
            Circle()
                .stroke(puckColor.opacity(0.4), lineWidth: 2)
                .frame(width: 28, height: 28)
            
            // Core Dot
            Circle()
                .fill(puckColor)
                .frame(width: 18, height: 18)
                .shadow(color: puckColor.opacity(0.8), radius: 4)
            
            // Coordinate readout mini tag
            VStack {
                Text(String(format: "(%.2f, %.2f)", contact.x, contact.y))
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(3)
                    .offset(y: -18)
            }
        }
    }
}
