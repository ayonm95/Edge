// Sources/Edge/UI/Settings/SettingsWindowController.swift
import AppKit
import SwiftUI

/// Standalone NSWindowController managing the Edge Preferences window.
/// Handles clean accessory activation, screen positioning, and lifecycle coordination.
@MainActor
public final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    
    // MARK: - Singleton
    public static let shared = SettingsWindowController()
    
    // MARK: - Constants
    private static let defaultWidth: CGFloat = 580
    private static let defaultHeight: CGFloat = 640
    private static let windowTitle = "Edge Settings"
    
    // MARK: - Initialization
    public init() {
        super.init(window: nil)
    }

    private func ensureWindow() -> NSWindow {
        if let existing = self.window {
            return existing
        }
        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: Self.defaultWidth,
            height: Self.defaultHeight
        )

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        self.window = window
        setupWindow(window)
        return window
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Window Configuration
    private func setupWindow(_ window: NSWindow) {
        window.title = Self.windowTitle
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.delegate = self
        
        // Fixed dimensions prevent layout distortion during slider adjustments
        window.minSize = NSSize(width: Self.defaultWidth, height: Self.defaultHeight)
        window.maxSize = NSSize(width: Self.defaultWidth, height: Self.defaultHeight + 100)
        
        // Host SwiftUI SettingsView
        let rootView = SettingsView()
        let hostingView = NSHostingView(rootView: rootView)
        window.contentView = hostingView
    }
    
    // MARK: - Presentation
    
    /// Presents and activates the settings window, positioning it near top-center.
    public func show() {
        let window = ensureWindow()
        
        if !window.isVisible {
            positionTopCenter(window)
        }
        
        // Activate app process even when running as accessory
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // Activate touch preview pipeline for real-time contact rendering
        TouchPreviewState.shared.isActive = true
    }
    
    /// Centers the window slightly above screen center for optimal visual ergonomics
    private func positionTopCenter(_ window: NSWindow) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            window.center()
            return
        }
        
        let visibleFrame = screen.visibleFrame
        let windowFrame = window.frame
        let x = visibleFrame.midX - (windowFrame.width / 2.0)
        let y = visibleFrame.midY - (windowFrame.height / 2.0) + (visibleFrame.height * 0.10)
        
        window.setFrameOrigin(NSPoint(x: round(x), y: round(y)))
    }
    
    // MARK: - NSWindowDelegate
    
    public func windowWillClose(_ notification: Notification) {
        // Deactivate live touch preview to conserve CPU cycles when window is dismissed
        TouchPreviewState.shared.isActive = false
        TouchPreviewState.shared.clearTouches()
    }
    
    public func windowDidBecomeKey(_ notification: Notification) {
        TouchPreviewState.shared.isActive = true
    }
}
