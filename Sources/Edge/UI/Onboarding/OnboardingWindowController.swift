// Sources/Edge/UI/Onboarding/OnboardingWindowController.swift
import AppKit
import SwiftUI

/// NSWindowController managing the first-run Accessibility Onboarding window.
@MainActor
public final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = OnboardingWindowController()

    private static let windowWidth: CGFloat = 500
    private static let windowHeight: CGFloat = 460
    private static let windowTitle = "Welcome to Edge"

    public init() {
        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: Self.windowWidth,
            height: Self.windowHeight
        )

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)
        setupWindow(window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow(_ window: NSWindow) {
        window.title = Self.windowTitle
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.center()

        let rootView = OnboardingView { [weak self] in
            self?.close()
        }
        let hostingView = NSHostingView(rootView: rootView)
        window.contentView = hostingView
    }

    /// Presents and activates the onboarding window.
    public func show() {
        guard let window = self.window else { return }

        if !window.isVisible {
            window.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    public func windowWillClose(_ notification: Notification) {
        // Stop high-frequency onboarding polling if running
        PermissionManager.shared.startPolling(interval: 2.0)
    }
}
