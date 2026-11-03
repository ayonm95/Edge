// Sources/Edge/UI/HUD/HUDWindowController.swift
import AppKit
import SwiftUI

/// Window controller hosting the floating On-Screen Display (OSD) HUD panel.
///
/// Features:
/// - Non-activating, borderless `NSPanel` (`[.borderless, .nonactivatingPanel]`).
/// - `.floating` window level, remaining visible above standard application spaces.
/// - Passes all mouse clicks through to background apps (`ignoresMouseEvents = true`).
/// - Anchored dynamically on the active display (horizontally centered, 140pt above bottom edge).
/// - Smooth 0.25s ease-out alpha fade-out and detach from compositor on idle.
/// - Generation-tracked `fadeToken` guarding against mid-fade interruption races.
@MainActor
public final class HUDWindowController: NSWindowController {
    public private(set) var panel: NSPanel?
    public private(set) var fadeToken: Int = 0
    public private(set) var isVisible: Bool = false

    public init(rootView: AnyView) {
        let hudPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        hudPanel.level = .floating
        hudPanel.isOpaque = false
        hudPanel.backgroundColor = .clear
        hudPanel.hasShadow = false
        hudPanel.ignoresMouseEvents = true
        hudPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
        hudPanel.isReleasedWhenClosed = false
        hudPanel.hidesOnDeactivate = false

        let hostingView = NSHostingView(rootView: rootView)
        hudPanel.contentView = hostingView

        super.init(window: hudPanel)
        self.panel = hudPanel
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Positions and presents the HUD on the target display with full opacity.
    public func show(on screen: NSScreen? = nil) {
        fadeToken &+= 1
        isVisible = true

        guard let panel = panel else { return }
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first

        if let targetScreen = targetScreen {
            position(on: targetScreen)
        }

        NSAnimationContext.beginGrouping()
        panel.animator().alphaValue = 1.0
        NSAnimationContext.endGrouping()

        panel.orderFrontRegardless()
    }

    /// Repositions the panel to the bottom-center of the specified display.
    public func position(on screen: NSScreen) {
        guard let panel = panel else { return }
        let screenRect = screen.frame
        let panelWidth: CGFloat = 260
        let panelHeight: CGFloat = 56
        let x = screenRect.origin.x + (screenRect.width - panelWidth) / 2.0
        let y = screenRect.origin.y + 140.0 // 140pt above bottom edge matching native macOS bezel
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }

    /// Smoothly animates the panel alpha to 0.0, detaching from compositor upon completion.
    public func fadeOut(duration: TimeInterval = 0.25, completion: (@Sendable () -> Void)? = nil) {
        fadeToken &+= 1
        let capturedToken = fadeToken

        guard let panel = panel, panel.isVisible else {
            self.isVisible = false
            completion?()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0.0
        } completionHandler: { [weak self, weak panel] in
            MainActor.assumeIsolated {
                guard let self = self, let panel = panel else { return }
                guard self.fadeToken == capturedToken else {
                    // Animation was interrupted by a new show() or fadeOut(): keep visible
                    return
                }
                panel.orderOut(nil)
                self.isVisible = false
                completion?()
            }
        }
    }

    /// Immediately orders the panel out without animation.
    public func dismissImmediately() {
        fadeToken &+= 1
        isVisible = false
        guard let panel = panel else { return }
        panel.alphaValue = 0.0
        panel.orderOut(nil)
    }
}
