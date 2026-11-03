// Sources/Edge/App/EdgeAppCoordinator.swift
import Foundation
import AppKit

/// Central orchestrator for the Edge macOS application.
/// Wires together the MultitouchBridge, EdgeGestureEngine, Hardware Controllers,
/// OSD HUD, Status Bar menu, and Permission Management.
@MainActor
public final class EdgeAppCoordinator: NSObject, EdgeGestureEngineDelegate, MultitouchBridgeDelegate {
    public static let shared = EdgeAppCoordinator()

    public let audioController: any AudioControlling
    public let brightnessManager: any BrightnessControlling
    public let mediaManager: any MediaControlling
    public let hudManager: any HUDManaging
    public let cursorManager: any CursorControlling
    public let hapticsManager: any HapticsPerforming
    public let statusBarController: StatusBarController
    public let preferencesHolder: AtomicPreferencesHolder
    public let gestureEngine: EdgeGestureEngine
    public let multitouchBridge: any MultitouchBridging
    public let permissionManager: PermissionManager

    private let stateLock = NSLock()
    private nonisolated(unsafe) var _activeEdge: EdgeLocation = .none
    private nonisolated(unsafe) var _isGestureActive: Bool = false
    public private(set) var isRunning: Bool = false
    public private(set) var isEnabled: Bool = true

    public nonisolated var activeEdge: EdgeLocation {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _activeEdge
    }

    public nonisolated var isGestureActive: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _isGestureActive
    }

    public override convenience init() {
        self.init(
            audioController: AudioController.shared,
            brightnessManager: BrightnessManager.shared,
            mediaManager: MediaManager.shared,
            hudManager: HUDManager.shared,
            cursorManager: CursorManager.shared,
            hapticsManager: HapticsManager.shared,
            statusBarController: StatusBarController.shared,
            preferencesHolder: Preferences.shared.atomicHolder,
            gestureEngine: EdgeGestureEngine(),
            multitouchBridge: MultitouchBridge(),
            permissionManager: PermissionManager.shared
        )
    }

    public init(
        audioController: any AudioControlling,
        brightnessManager: any BrightnessControlling,
        mediaManager: any MediaControlling,
        hudManager: any HUDManaging,
        cursorManager: any CursorControlling,
        hapticsManager: any HapticsPerforming,
        statusBarController: StatusBarController,
        preferencesHolder: AtomicPreferencesHolder,
        gestureEngine: EdgeGestureEngine,
        multitouchBridge: any MultitouchBridging,
        permissionManager: PermissionManager
    ) {
        self.audioController = audioController
        self.brightnessManager = brightnessManager
        self.mediaManager = mediaManager
        self.hudManager = hudManager
        self.cursorManager = cursorManager
        self.hapticsManager = hapticsManager
        self.statusBarController = statusBarController
        self.preferencesHolder = preferencesHolder
        self.gestureEngine = gestureEngine
        self.multitouchBridge = multitouchBridge
        self.permissionManager = permissionManager

        super.init()

        // Inject preferences to bridge if supported
        if let concreteBridge = multitouchBridge as? MultitouchBridge {
            concreteBridge.preferencesHolder = preferencesHolder
        }

        self.gestureEngine.delegate = self
        self.multitouchBridge.setDelegate(self)

        setupListeners()
        setupStatusBarCallbacks()
    }

    // MARK: - Setup & Wiring

    private func setupListeners() {
        // Wire external CoreAudio hardware changes to HUD
        audioController.setVolumeListener { [weak self] vol, muted in
            guard let self = self else { return }
            let prefs = self.preferencesHolder.get()
            guard prefs.showOSD else { return }

            Task { @MainActor [weak self] in
                self?.hudManager.showVolume(level: vol, isMuted: muted)
            }
        }

        // Wire permission changes dynamically
        permissionManager.onTrustChanged = { [weak self] isTrusted in
            guard let self = self else { return }
            self.handleTrustChanged(isTrusted)
        }
    }

    private func setupStatusBarCallbacks() {
        statusBarController.onToggleEnable = { [weak self] enable in
            self?.setEnabled(enable)
        }

        statusBarController.onOpenSettings = {
            SettingsWindowController.shared.show()
        }

        statusBarController.onOpenOnboarding = {
            OnboardingWindowController.shared.show()
        }

        statusBarController.onCheckPermissions = { [weak self] in
            guard let self = self else { return }
            let trusted = self.permissionManager.promptAccessibility()
            if !trusted {
                OnboardingWindowController.shared.show()
            }
        }

        statusBarController.onQuit = {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Lifecycle

    public func start() {
        let isTrusted = PermissionManager.checkIsTrusted()
        self.isEnabled = preferencesHolder.get().isEnabled

        self.statusBarController.updateStatus(
            isEnabled: self.isEnabled,
            isAccessibilityGranted: isTrusted
        )

        // Always start the multitouch bridge so volume, brightness,
        // haptics, HUD, and live trackpad preview work immediately!
        startBridgeIfAllowed()

        if !isTrusted {
            // Guide user on initial launch
            permissionManager.startPolling(interval: 1.0)
            OnboardingWindowController.shared.show()
        }

        isRunning = true
    }

    public func stop() {
        multitouchBridge.stop()
        permissionManager.stopPolling()
        isRunning = false
    }

    public func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
        var prefs = preferencesHolder.get()
        prefs.isEnabled = enabled
        preferencesHolder.set(prefs)

        let isTrusted = permissionManager.isTrusted
        self.statusBarController.updateStatus(
            isEnabled: enabled,
            isAccessibilityGranted: isTrusted
        )

        if enabled {
            startBridgeIfAllowed()
        } else {
            multitouchBridge.stop()
        }
    }

    private func handleTrustChanged(_ isTrusted: Bool) {
        self.statusBarController.updateStatus(
            isEnabled: self.isEnabled,
            isAccessibilityGranted: isTrusted
        )

        if isTrusted && isEnabled {
            startBridgeIfAllowed()
        }
    }

    private func startBridgeIfAllowed() {
        guard isEnabled else { return }
        do {
            try multitouchBridge.start()
        } catch {
            print("[EdgeAppCoordinator] Warning: Could not start multitouch bridge: \(error.localizedDescription)")
        }
    }

    // MARK: - MultitouchBridgeDelegate

    nonisolated public func multitouchBridge(
        _ bridge: any MultitouchBridging,
        didReceiveTouches touches: [MTTouch],
        deviceKind: MultitouchDeviceKind,
        isBuiltIn: Bool,
        timestamp: Double,
        frame: Int32
    ) {
        let prefs = preferencesHolder.get()
        guard prefs.isEnabled else { return }

        // Live preview updates ONLY when Settings window is open.
        // Fast synchronous check eliminates 120 heap Tasks per second during normal trackpad usage!
        if TouchPreviewState.isLivePreviewActive {
            Task { @MainActor in
                let points = touches.map {
                    (
                        id: Int($0.fingerID),
                        x: Double($0.normalizedVector.position.x),
                        y: Double($0.normalizedVector.position.y)
                    )
                }
                TouchPreviewState.shared.updateHardwareTouches(
                    points: points,
                    edgeWidth: prefs.edgeWidth,
                    activeArea: prefs.activeArea,
                    swapSides: prefs.swapSides
                )
            }
        }

        // Process touch frame through gesture FSM
        gestureEngine.processFrame(
            touches: touches,
            preferences: prefs,
            cursorManager: cursorManager,
            hapticsManager: hapticsManager
        )
    }

    // MARK: - EdgeGestureEngineDelegate

    nonisolated public func handleGestureAction(_ action: EdgeGestureAction) {
        let prefs = preferencesHolder.get()

        switch action {
        case .gestureStarted(let edge):
            stateLock.lock()
            _activeEdge = edge
            _isGestureActive = true
            stateLock.unlock()

            Task { @MainActor [weak self] in
                self?.statusBarController.setTrackingState(true)
                self?.hudManager.cancelDismissTimer()
            }

        case .gestureEnded:
            stateLock.lock()
            _activeEdge = .none
            _isGestureActive = false
            stateLock.unlock()

            Task { @MainActor [weak self] in
                self?.statusBarController.setTrackingState(false)
                if prefs.showOSD {
                    self?.hudManager.scheduleDismiss(delay: 0.8)
                }
            }

        case .volumeDelta(let delta):
            let current = audioController.getVolume()
            let newVolume = min(max(current + delta, 0.0), 1.0)
            audioController.setVolume(newVolume)
            if prefs.showOSD {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.hudManager.showVolume(level: newVolume, isMuted: self.audioController.isMuted())
                }
            }

        case .brightnessDelta(let delta):
            let current = brightnessManager.getBrightness()
            let newBrightness = min(max(current + delta, 0.0), 1.0)
            brightnessManager.setBrightness(newBrightness)
            if prefs.showOSD {
                Task { @MainActor [weak self] in
                    self?.hudManager.showBrightness(level: newBrightness)
                }
            }

        case .quickMute:
            let isMuted = audioController.toggleMute()
            if prefs.showOSD {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.hudManager.showVolume(level: self.audioController.getVolume(), isMuted: isMuted)
                    self.hudManager.scheduleDismiss(delay: 1.0)
                }
            }

        case .mediaPlayPause:
            mediaManager.playPause()
            if prefs.showOSD {
                Task { @MainActor [weak self] in
                    self?.hudManager.showMedia(action: .playPause)
                    self?.hudManager.scheduleDismiss(delay: 1.0)
                }
            }

        case .mediaNext:
            mediaManager.nextTrack()
            if prefs.showOSD {
                Task { @MainActor [weak self] in
                    self?.hudManager.showMedia(action: .nextTrack)
                    self?.hudManager.scheduleDismiss(delay: 1.0)
                }
            }

        case .mediaPrevious:
            mediaManager.previousTrack()
            if prefs.showOSD {
                Task { @MainActor [weak self] in
                    self?.hudManager.showMedia(action: .previousTrack)
                    self?.hudManager.scheduleDismiss(delay: 1.0)
                }
            }
        }
    }
}
