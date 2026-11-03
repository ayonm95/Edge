// Sources/Edge/main.swift
import AppKit

// Enforce accessory activation policy (no dock icon, background menu bar agent)
// This guarantees dock icon suppression in both direct CLI ('swift run') and packaged app execution.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    // Attach application delegate
    let delegate = EdgeAppDelegate()
    app.delegate = delegate

    // Start AppKit event runloop
    app.run()
}
