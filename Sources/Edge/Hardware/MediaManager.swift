// Sources/Edge/Hardware/MediaManager.swift
import Foundation
import AppKit
import CoreGraphics

/// System-defined auxiliary media playback actions.
public enum MediaAction: String, Sendable, Equatable, CaseIterable {
    case playPause = "playPause"
    case nextTrack = "nextTrack"
    case previousTrack = "previousTrack"
    case fastForward = "fastForward"
    case rewind = "rewind"

    /// Key code mapping defined in macOS `hidsystem/ev_keymap.h`.
    public var keyType: Int32 {
        switch self {
        case .playPause: return 16     // NX_KEYTYPE_PLAY
        case .nextTrack: return 17     // NX_KEYTYPE_NEXT
        case .previousTrack: return 18 // NX_KEYTYPE_PREVIOUS
        case .fastForward: return 19   // NX_KEYTYPE_FAST
        case .rewind: return 20        // NX_KEYTYPE_REWIND
        }
    }
}

/// Protocol defining media playback control.
public protocol MediaControlling: Sendable {
    func playPause()
    func nextTrack()
    func previousTrack()
}

/// Hardware media controller synthesizing macOS auxiliary system HID events.
///
/// Dispatches `NX_SYSDEFINED` subtype 8 (`NX_SUBTYPE_AUX_CONTROL_BUTTONS`) events to `.cghidEventTap`
/// to control media playback across Apple Music, Spotify, YouTube, Safari, Chrome, VLC, and IINA.
///
/// Features:
/// - Paired KeyDown and KeyUp event synthesis.
/// - Bidirectional "Reverse Media Swipe" resolution for trackpad bottom strip.
/// - Optional callback hook for unit testing and observability.
public final class MediaManager: MediaControlling, @unchecked Sendable {
    public static let shared = MediaManager()

    private let lock = NSLock()
    public var onActionTriggered: (@Sendable (MediaAction) -> Void)?

    public init() {}

    // MARK: - MediaControlling Protocol Implementation

    public func playPause() {
        triggerAction(.playPause)
    }

    public func nextTrack() {
        triggerAction(.nextTrack)
    }

    public func previousTrack() {
        triggerAction(.previousTrack)
    }

    // MARK: - Action Dispatch

    /// Triggers the specified media action by posting system key events.
    public func triggerAction(_ action: MediaAction) {
        postMediaKey(keyCode: action.keyType)

        lock.lock()
        let handler = onActionTriggered
        lock.unlock()
        handler?(action)
    }

    /// Evaluates horizontal delta on the bottom trackpad strip according to the reverseMediaSwipe setting.
    @discardableResult
    public func handleBottomEdgeSwipe(deltaX: CGFloat, reversed: Bool) -> MediaAction? {
        guard abs(deltaX) > 0.001 else { return nil }
        let isRightSwipe = deltaX > 0
        let triggerNext = reversed ? !isRightSwipe : isRightSwipe

        let action: MediaAction = triggerNext ? .nextTrack : .previousTrack
        triggerAction(action)
        return action
    }

    // MARK: - Low-Level HID Key Synthesis

    private func postMediaKey(keyCode: Int32) {
        func createEvent(keyDown: Bool) -> NSEvent? {
            let state: Int32 = keyDown ? 0xA : 0xB
            let data1 = Int((keyCode << 16) | (state << 8))
            return NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8, // NX_SUBTYPE_AUX_CONTROL_BUTTONS
                data1: data1,
                data2: -1
            )
        }

        guard let downEvent = createEvent(keyDown: true)?.cgEvent,
              let upEvent = createEvent(keyDown: false)?.cgEvent else {
            return
        }

        downEvent.post(tap: .cghidEventTap)
        upEvent.post(tap: .cghidEventTap)
    }
}
