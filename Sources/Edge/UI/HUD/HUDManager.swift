// Sources/Edge/UI/HUD/HUDManager.swift
import AppKit
import SwiftUI

/// Distinct categories of visual feedback presented by the OSD HUD.
public enum HUDItem: Equatable, Sendable {
    case volume(level: Float, isMuted: Bool)
    case brightness(level: Float)
    case media(action: MediaAction)
}

/// Protocol defining the On-Screen Display HUD coordination interface.
@MainActor
public protocol HUDManaging: AnyObject, Sendable {
    func showVolume(level: Float, isMuted: Bool)
    func showBrightness(level: Float)
    func showMedia(action: MediaAction)
    func dismissImmediately()
    func scheduleDismiss(delay: TimeInterval)
    func cancelDismissTimer()
}

public extension HUDManaging {
    func scheduleDismiss(delay: TimeInterval = 1.0) {}
    func cancelDismissTimer() {}
}

/// Actor-isolated HUD coordinator managing the lifecycle, rendering, and auto-dismiss of the OSD overlay.
///
/// Features:
/// - Reactive state updates through `@Published` properties for SwiftUI.
/// - Debounced 1.0s auto-dismiss timer that automatically pauses during active dragging.
/// - Smooth 0.25s ease-out alpha fade-out.
/// - Mid-fade interruption recovery without visual jitter.
/// - Detaches from compositor on idle for 0 CPU / 0 GPU overhead.
@MainActor
public final class HUDManager: ObservableObject, HUDManaging, @unchecked Sendable {
    public static let shared = HUDManager()

    @Published public private(set) var currentItem: HUDItem = .volume(level: 0.5, isMuted: false)
    @Published public private(set) var isVisible: Bool = false

    public private(set) var windowController: HUDWindowController?
    private var dismissTask: Task<Void, Never>?

    public init() {}

    // MARK: - HUDManaging Protocol Implementation

    public func showVolume(level: Float, isMuted: Bool) {
        show(item: .volume(level: level, isMuted: isMuted))
    }

    public func showBrightness(level: Float) {
        show(item: .brightness(level: level))
    }

    public func showMedia(action: MediaAction) {
        show(item: .media(action: action))
    }

    public func dismissImmediately() {
        cancelDismissTimer()
        isVisible = false
        windowController?.dismissImmediately()
    }

    // MARK: - Lifecycle & Presentation

    /// Displays the specified HUD item on the given or active display.
    public func show(item: HUDItem, on screen: NSScreen? = nil) {
        cancelDismissTimer()
        currentItem = item
        isVisible = true

        let controller = ensureWindowController()
        controller.show(on: screen)

        scheduleDismiss(delay: 1.0)
    }

    /// Cancels pending auto-dismiss timer. Called while the user is actively sliding.
    public func cancelDismissTimer() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    /// Schedules debounced auto-dismiss after the specified delay.
    public func scheduleDismiss(delay: TimeInterval = 1.0) {
        cancelDismissTimer()
        dismissTask = Task { @MainActor [weak self] in
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }

            guard let self = self else { return }
            self.windowController?.fadeOut(duration: 0.25) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.dismissTask == nil || self.dismissTask?.isCancelled == false {
                        self.isVisible = false
                    }
                }
            }
        }
    }

    private func ensureWindowController() -> HUDWindowController {
        if let controller = windowController {
            return controller
        }
        let controller = HUDWindowController(rootView: AnyView(HUDContainerView(manager: self)))
        self.windowController = controller
        return controller
    }
}
