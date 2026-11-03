# Project: Edge (Edge Slider macOS Menu Bar App)

## Architecture

Edge is a lightweight, low-overhead macOS menu bar application (`LSUIElement = true`) written in modern Swift / SwiftUI for macOS 13+. It allows users to control system volume, display brightness, quick mute, and media playback using subtle edge touch gestures and swipes along the boundaries of their Apple MacBook trackpad or Magic Trackpad, accompanied by haptic feedback and a floating liquid-glass OSD HUD.

```
                          ┌──────────────────────────────────────────────┐
                          │         macOS MultitouchSupport C API        │
                          └──────────────────────┬───────────────────────┘
                                                 │ raw contact frames (120Hz)
                                                 ▼
                          ┌──────────────────────────────────────────────┐
                          │               MultitouchBridge               │
                          │   (dlopen / dlsym / C callback with refcon)  │
                          └──────────────────────┬───────────────────────┘
                                                 │ normalized MTTouch stream
                                                 ▼
                          ┌──────────────────────────────────────────────┐
                          │             EdgeGestureEngine                │
                          │  - Boundary math (Left, Right, Bottom, Corner)│
                          │  - 4-State FSM (Idle -> Candidate -> Slide)  │
                          │  - Double-Tap Detector (<300ms)              │
                          │  - Cursor Freeze (Hide + Warp + Tap Suppress)│
                          │  - Haptics (NSHapticFeedbackManager ticks)   │
                          └──────────────┬───────────────────────────────┘
                                         │ Action events
                                         ▼
                          ┌──────────────────────────────────────────────┐
                          │              EdgeAppCoordinator             │
                          │        (Wires gestures to controllers)       │
                          └──────┬───────────────┬───────────────┬───────┘
                                 │               │               │
        ┌────────────────────────┘               │               └────────────────────────┐
        ▼                                        ▼                                        ▼
┌─────────────────────────┐          ┌───────────────────────┐          ┌─────────────────────────┐
│     AudioController     │          │   BrightnessManager   │          │      MediaManager       │
│ - CoreAudio HAL C API   │          │ - DisplayServices C   │          │ - NX_SYSDEFINED AUX     │
│ - Volume scalar 0.0-1.0 │          │ - CoreDisplay fallback│          │   Control Buttons       │
│ - Channel fallback      │          │ - Active display      │          │ - Play/Pause, Next/Prev │
│ - Property listeners    │          │ - 0.0 - 1.0 scalar    │          │ - Reverse swipe logic   │
└────────────┬────────────┘          └───────────┬───────────┘          └────────────┬────────────┘
             │                                   │                                   │
             └───────────────────────────────────┼───────────────────────────────────┘
                                                 │ Updates
                                                 ▼
                                     ┌───────────────────────┐
                                     │      HUDManager       │
                                     │ - Non-activating NSPanel│
                                     │ - Liquid glass SwiftUI│
                                     │ - Debounced dismiss   │
                                     └───────────────────────┘
                                                 ▲
                                                 │ User config
                                     ┌───────────┴───────────┐
                                     │      Preferences      │
                                     │ - SwiftUI Observable  │
                                     │ - AtomicSnapshot      │
                                     │ - SMAppService login  │
                                     └───────────────────────┘
                                                 ▲
                                                 │
                                     ┌───────────┴───────────┐
                                     │   StatusBarController │
                                     │ - NSStatusItem        │
                                     │ - Settings / Onboarding│
                                     └───────────────────────┘
```

---

## Code Layout

```
Edge/
├── Package.swift                             # SwiftPM executable manifest (macOS 13+)
├── scripts/
│   └── bundle.sh                             # Builds and packages Edge.app with Info.plist
├── Sources/
│   └── Edge/
│       ├── main.swift                        # App entry point, NSApplication initialization
│       ├── App/
│       │   ├── EdgeApp.swift                 # App lifecycle, NSApplicationDelegate, coordinator boot
│       │   ├── StatusBarController.swift     # NSStatusItem, menu layout, status icons
│       │   └── PermissionManager.swift       # Accessibility verification, polling & deep link
│       ├── Model/
│       │   ├── Preferences.swift             # MainActor Observable settings for SwiftUI
│       │   ├── PreferencesSnapshot.swift     # Immutable Sendable snapshot for 120Hz gesture engine
│       │   └── AtomicPreferencesHolder.swift # os_unfair_lock thread-safe snapshot storage
│       ├── UI/
│       │   ├── Settings/
│       │   │   ├── SettingsWindowController.swift # Standalone NSWindowController for preferences
│       │   │   └── SettingsView.swift             # SwiftUI settings sliders, toggles & pickers
│       │   ├── Onboarding/
│       │   │   ├── OnboardingWindowController.swift # First-run accessibility guidance window
│       │   │   └── OnboardingView.swift             # SwiftUI accessibility onboarding instructions
│       │   └── HUD/
│       │       ├── HUDWindowController.swift        # Floating non-activating NSPanel OSD
│       │       ├── HUDContainerView.swift           # Liquid glass capsule HUD in SwiftUI
│       │       └── HUDManager.swift                 # Actor-isolated debounced show/fade/hide controller
│       ├── Hardware/
│       │   ├── AudioController.swift                # CoreAudio HAL C API volume & mute controller
│       │   ├── BrightnessManager.swift              # DisplayServices & CoreDisplay dynamic loader
│       │   └── MediaManager.swift                   # System-defined media key simulation (NX_SYSDEFINED)
│       └── Gesture/
│           ├── Multitouch/
│           │   ├── MultitouchTypes.swift            # MTTouch, MTPoint, MTVector structs & enums
│           │   └── MultitouchBridge.swift           # dlopen/dlsym bridge with refcon C callback
│           ├── Cursor/
│           │   └── CursorManager.swift              # Hide, warp, and CGEventTap pointer suppression
│           ├── Haptics/
│           │   └── HapticsManager.swift             # NSHapticFeedbackManager performer for ticks
│           └── Engine/
│               ├── GestureState.swift               # 4-State FSM enum (Idle, Candidate, Sliding, Ending)
│               └── EdgeGestureEngine.swift          # Boundary math, filtering, velocity, double-tap
└── Tests/
    └── EdgeTests/
        ├── Unit/
        │   ├── PreferencesTests.swift               # Preference serialization and snapshotting
        │   ├── EdgeMathTests.swift                  # Coordinate normalizer and boundary math
        │   ├── GestureFSMTests.swift                # FSM state transition test suite
        │   ├── HardwareMockTests.swift              # Volume/Brightness/Media controller mock tests
        │   └── HUDStateTests.swift                  # HUD debouncing and state rendering tests
        └── E2E/
            ├── TestHarness.swift                    # Synthetic touch injection & assertion harness
            ├── Tier1_FeatureTests.swift             # Baseline isolated feature tests (>=5 per feature)
            ├── Tier2_BoundaryTests.swift            # Corner, deadzone & extreme input tests (>=5/feat)
            ├── Tier3_CombinationTests.swift         # Multi-feature & concurrency interactions
            ├── Tier4_ScenarioTests.swift            # Real-world daily usage workflows
            └── Tier5_AdversarialTests.swift          # Hardening, rapid jitter & edge abuse tests
```

---

## Feature Inventory

Every requirement from the user specification and technical survey is tracked here with its assigned milestone.

| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Menu Bar Extra & Icon States | `NSStatusItem` with dynamic template icons (idle, active, alert, disabled) | M1 | Request §2 |
| 2 | Background Agent (LSUIElement) | Dockless background operation via `Info.plist` and runtime `.accessory` policy | M1 | Request §2 |
| 3 | Preferences Model & Snapshotting | High-performance two-tier preferences (`@Observable` UI + atomic immutable snapshot) | M1 | Survey 1 |
| 4 | Settings Window | Dedicated `NSWindow` with SwiftUI `SettingsView` allowing live trackpad testing | M1 | Request §2 |
| 5 | Side Swapping Toggle | Switch Volume (Right/Left) and Brightness (Left/Right) | M1 | Request §2 |
| 6 | Edge Width & Sensitivity Sliders | Configurable margin width (0.03–0.20) and gesture velocity multiplier (0.5x–2.5x) | M1 | Request §2 |
| 7 | Active Area Restrictions | Restrict edge triggers to Entire Edge, Bottom 3/4, Bottom Half, or Bottom 1/4 | M1 | Request §2 |
| 8 | Reverse Media Swipe Toggle | Configurable direction for next/previous track horizontal swipe | M1 | Request §2 |
| 9 | Precise Sliding Toggle | Global quarter-step (1/64th) volume/brightness sensitivity mode | M1 | Request §2 |
| 10 | Magic Mouse Toggle | Enable or disable edge gesture processing on external Magic Mouse surfaces | M1 | Request §2 |
| 11 | Launch at Login | Modern `SMAppService.mainApp` auto-start integration with status checking | M1 | Request §2 |
| 12 | App Bundling Script | Automated `bundle.sh` creating `Edge.app` with `Info.plist` | M1 | Survey 1 |
| 13 | CoreAudio Master Volume Control | Native volume adjustment (0.0 to 1.0) using CoreAudio HAL C API | M2 | Request §3 |
| 14 | Hardware Volume Change Listener | Bidirectional sync via `AudioObjectAddPropertyListenerBlock` | M2 | Survey 2 |
| 15 | Quick Mute & State Machine | Instant mute toggle with un-mute volume restoration | M2 | Request §3 |
| 16 | Display Brightness Control | Dynamic `DisplayServicesSetBrightness` with `CoreDisplay` fallback | M2 | Request §3 |
| 17 | Multi-Display Targeting | Identify and adjust brightness for cursor-associated display | M2 | Survey 2 |
| 18 | Media Playback Key Simulation | Synthesize `NX_SYSDEFINED` subtype 8 events to `.cghidEventTap` | M2 | Request §3 |
| 19 | Bottom Edge Media Strip Actions | Next track, previous track, and play/pause key execution | M2 | Request §3 |
| 20 | Floating OSD HUD Window | Non-activating, borderless, floating `NSPanel` ignoring mouse events | M2 | Request §3 |
| 21 | Liquid Glass HUD UI | SwiftUI capsule HUD with `.ultraThinMaterial`, SF Symbols & progress bar | M2 | Survey 2 |
| 22 | Debounced HUD Auto-Dismiss | 1.0s idle timer with 0.25s ease-out fade; cancelled during active drags | M2 | Survey 2 |
| 23 | MultitouchSupport Dynamic Bridge | `dlopen`/`dlsym` binding for `MTDeviceCreateList` and contact callbacks | M3 | Request §3 |
| 24 | MTTouch C Callback with Refcon | Context-carrying C callback passing frames to Swift instance without global state | M3 | Survey 3 |
| 25 | Edge Boundary Coordinate Math | Normalized coordinate mapping with bottom-left origin `(0.0, 0.0)` | M3 | Request §3 |
| 26 | 4-State Gesture FSM | `Idle` -> `EdgeTouchCandidate` -> `Sliding` -> `Ending` with directional locking | M3 | Survey 3 |
| 27 | Double-Tap Detector | Inter-tap interval (<300ms) and spatial radius (<0.04) detector | M3 | Request §3 |
| 28 | Triple-Layer Cursor Freeze | `CGDisplayHideCursor`, `CGWarpMouseCursorPosition`, and event tap suppression | M3 | Request §3 |
| 29 | Haptic Step Performer | `NSHapticFeedbackManager.defaultPerformer.perform(.generic)` on discrete ticks | M3 | Request §3 |
| 30 | Shift-Option Precision Modifier | Global hardware modifier detection via `CGEventSource.flagsState` | M3 | Request §3 |
| 31 | Accessibility Verification | Check `AXIsProcessTrusted()` and prompt `AXIsProcessTrustedWithOptions` | M4 | Request §4 |
| 32 | Onboarding Window & Polling | Guidance UI with deep link `x-apple.systempreferences:` and 1.0s auto-detect | M4 | Request §4 |
| 33 | EdgeAppCoordinator | Unified central coordinator orchestrating gestures, hardware, HUD, and status | M4 | Request §1 |
| 34 | E2E Testing Suite (Tiers 1-4) | Comprehensive synthetic injection test suite verifying 100% features | M5 | Request §5 |
| 35 | Adversarial Hardening (Tier 5) | Stress, high-frequency scrubbing, boundary jitter, and race condition tests | M5 | Project Pattern |

---

## Milestones

| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | App Skeleton, Menu Bar & Settings | MenuBarExtra/NSStatusItem, Settings UI, Preferences Model, Open at Login, Package structure | none | DONE |
| M2 | Hardware Controllers & OSD HUD | CoreAudio volume & mute, DisplayServices brightness, Media keys, Floating SwiftUI HUD | M1 | DONE |
| M3 | Multitouch Engine & Gesture Engine | MultitouchSupport bridge, coordinate math, 4-state FSM, cursor freeze, haptics, modifier detection | M1 | IN_PROGRESS |
| M4 | Integration & Permissions Onboarding | EdgeAppCoordinator, Accessibility verification, onboarding flow, full app assembly | M1, M2, M3 | PLANNED |
| M5 | 100% E2E Test Suite & Adversarial Hardening | Phase 1: Pass 100% E2E tests (Tiers 1-4); Phase 2: Tier 5 adversarial hardening | M4, TEST_READY | PLANNED |

---

## Interface Contracts

### 1. Model & Preferences
```swift
public struct PreferencesSnapshot: Sendable, Codable, Equatable {
    public var swapSides: Bool
    public var edgeWidth: Double          // 0.03 - 0.20 (normalized)
    public var sensitivity: Double        // 0.5 - 2.5 multiplier
    public var activeArea: ActiveAreaZone // entire, bottomThreeQuarters, bottomHalf, bottomQuarter
    public var reverseMediaSwipe: Bool
    public var preciseSliding: Bool
    public var enableMagicMouse: Bool
    public var showOSD: Bool
    public var enableHaptics: Bool
}

public final class AtomicPreferencesHolder: @unchecked Sendable {
    public func get() -> PreferencesSnapshot
    public func set(_ snapshot: PreferencesSnapshot)
}
```

### 2. Hardware Controllers ↔ App Coordinator
```swift
public protocol AudioControlling: Sendable {
    func getVolume() -> Float
    func setVolume(_ volume: Float)
    func isMuted() -> Bool
    func toggleMute() -> Bool
    func setVolumeListener(_ listener: @escaping @Sendable (Float, Bool) -> Void)
}

public protocol BrightnessControlling: Sendable {
    func getBrightness() -> Float
    func setBrightness(_ brightness: Float)
}

public protocol MediaControlling: Sendable {
    func playPause()
    func nextTrack()
    func previousTrack()
}
```

### 3. HUD Manager ↔ App Coordinator
```swift
@MainActor
public protocol HUDManaging: AnyObject {
    func showVolume(level: Float, isMuted: Bool)
    func showBrightness(level: Float)
    func showMedia(action: MediaAction)
    func dismissImmediately()
}
```

### 4. Gesture Engine ↔ App Coordinator
```swift
public enum EdgeGestureAction: Sendable, Equatable {
    case volumeDelta(Float)
    case brightnessDelta(Float)
    case quickMute
    case mediaPlayPause
    case mediaNext
    case mediaPrevious
    case gestureStarted(edge: EdgeLocation)
    case gestureEnded
}

public protocol EdgeGestureEngineDelegate: AnyObject, Sendable {
    func handleGestureAction(_ action: EdgeGestureAction)
}
```

---

## Dual Track: E2E Testing Track

In parallel with implementation, the E2E Testing Track builds an opaque-box test runner and test cases structured into 5 tiers:
- **Tier 1**: Baseline feature coverage (>=5 tests per inventoried feature)
- **Tier 2**: Boundary & corner cases (extremes, zero values, edge bounds, jitter)
- **Tier 3**: Cross-feature combinations (side swapping + sensitivity, reverse media + double-tap)
- **Tier 4**: Real-world application scenarios (rapid volume adjustments during media playback)
- **Tier 5**: Adversarial stress testing (high-frequency touch floods, simulated driver reconnects)

The project will produce `TEST_READY.md` upon completion of the test harness and Tiers 1-4, which gates Milestone 5.
