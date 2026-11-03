// Sources/Edge/UI/HUD/HUDContainerView.swift
import SwiftUI

/// Top-level liquid-glass SwiftUI container for the floating On-Screen Display HUD.
public struct HUDContainerView: View {
    @ObservedObject public var manager: HUDManager

    public init(manager: HUDManager) {
        self.manager = manager
    }

    public var body: some View {
        Group {
            switch manager.currentItem {
            case .volume(let level, let isMuted):
                VolumeHUDView(level: level, isMuted: isMuted)
            case .brightness(let level):
                BrightnessHUDView(level: level)
            case .media(let action):
                MediaHUDView(action: action)
            }
        }
        .frame(width: 260, height: 56)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.25))

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            }
        )
        .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 12)
    }
}

/// Volume OSD HUD representation with dynamic speaker symbol and animated progress bar.
public struct VolumeHUDView: View {
    public let level: Float
    public let isMuted: Bool

    public init(level: Float, isMuted: Bool) {
        self.level = level
        self.isMuted = isMuted
    }

    private var iconName: String {
        if isMuted || level == 0 {
            return "speaker.slash.fill"
        } else if level < 0.33 {
            return "speaker.wave.1.fill"
        } else if level < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(isMuted ? Color.orange : Color.white)
                .frame(width: 26)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 7)

                    Capsule()
                        .fill(isMuted ? Color.gray : Color.white)
                        .frame(width: isMuted ? 0 : geo.size.width * CGFloat(max(0, min(1, level))), height: 7)
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: level)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 14)

            Text(isMuted ? "Muted" : "\(Int(round(level * 100)))%")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(isMuted ? Color.secondary : Color.white)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 18)
    }
}

/// Display Brightness OSD HUD representation with dynamic sun symbol and progress bar.
public struct BrightnessHUDView: View {
    public let level: Float

    public init(level: Float) {
        self.level = level
    }

    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: level < 0.5 ? "sun.min.fill" : "sun.max.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(Color.white)
                .frame(width: 26)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 7)

                    Capsule()
                        .fill(Color.white)
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, level))), height: 7)
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: level)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 14)

            Text("\(Int(round(level * 100)))%")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Color.white)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 18)
    }
}

/// Media Action OSD HUD representation with media symbols and action title.
public struct MediaHUDView: View {
    public let action: MediaAction

    public init(action: MediaAction) {
        self.action = action
    }

    private var iconAndTitle: (String, String) {
        switch action {
        case .playPause: return ("playpause.fill", "Play / Pause")
        case .nextTrack: return ("forward.fill", "Next Track")
        case .previousTrack: return ("backward.fill", "Previous Track")
        case .fastForward: return ("forward.end.fill", "Fast Forward")
        case .rewind: return ("backward.end.fill", "Rewind")
        }
    }

    public var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconAndTitle.0)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.white)
                .frame(width: 32)

            Text(iconAndTitle.1)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white)

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
