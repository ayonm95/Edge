# Edge (Trackpad Edge Slider for macOS)

<p align="center">
  <img src="Sources/Edge/Resources/AppIcon_1024.png" width="128" height="128" alt="Edge App Icon" style="border-radius: 28px; box-shadow: 0 8px 24px rgba(0,0,0,0.3);" />
</p>

A native macOS menu bar application that turns the physical boundaries of your MacBook trackpad or Magic Trackpad into precise hardware sliders for volume and screen brightness, with quick mute, media navigation, haptic feedback, and a floating liquid-glass OSD HUD.

Built in 100% pure Swift & SwiftUI with zero third-party framework dependencies.

---

## Features

- **Two-Finger Edge Sliding:**
  - **Right Edge:** Smooth system volume adjustment via a 2-finger swipe with native OSD HUD feedback.
  - **Left Edge:** Display brightness adjustment via a 2-finger swipe with native OSD HUD feedback.
  - **Accidental Touch Immunity:** 2-finger sliding ensures your regular single-finger mouse cursor navigation never accidentally modulates volume or brightness.
  - **Swappable Sides:** Invert volume and brightness edges with one click in Settings.
- **Single-Finger Quick Mute:** Double-tap the top-right corner with 1 finger to instantly toggle mute and restore your prior audio volume level.
- **Bottom Media Strip:**
  - **Swipe Left/Right:** Skip forward or backward across tracks in Apple Music, Spotify, YouTube, etc. (supports configurable Reverse Swipe).
  - **Double-Tap:** Instant Play / Pause toggle.
- **Tactile Haptic Feedback:** Emits light ticks (`NSHapticFeedbackManager`) under your finger at each discrete volume / brightness step increment.
- **Fine / Precise Control:**
  - Hold **Shift + Option** while sliding to drop down to micro quarter-steps (1/64th step adjustments).
  - Or enable **Precise Sliding** in Settings for permanent micro-control without holding keys.
- **Triple-Layer Cursor Freeze:** Locks and hides the cursor while dragging along the edge, preventing pointer drift across the screen.
- **Active Area Constraints:** Restrict edge activation to the Entire Edge, Bottom 3/4, Bottom Half, or Bottom 1/4 (preventing accidental thumb activations near the top).
- **Interactive Trackpad Visualizer:** Live SwiftUI Settings panel displays real-time trackpad touch points and zone boundaries as you touch the glass.
- **Magic Mouse Support:** Optionally enable or isolate external Magic Mouse touch events.
- **Zero-Footprint Menu Bar Utility:** Operates as a background agent (`LSUIElement = true`) with dynamic status icons (`idle`, `tracking`, `paused`, `warning`), uses near-zero CPU and memory at idle, and supports **Open at Login** (`SMAppService`).
- **Hide Menu Bar Icon Option:** Easily toggle menu bar icon visibility in Settings (`General -> Menu Bar`) for an ultra-minimalist, distraction-free desktop. When hidden, simply open Edge from Applications or Spotlight to access Settings.
- **Ultra-Responsive 120Hz CoreAudio HAL Pipeline:** Volume adjustments feature non-blocking asynchronous CoreAudio dispatch and intelligent corner-to-slide transition, ensuring silky smooth response with zero dropped frames.

---

## Architecture Overview

```
                               ┌──────────────────────────────────────────────┐
                               │       macOS MultitouchSupport Framework      │
                               └──────────────────────┬───────────────────────┘
                                                      │ raw contact frames (120Hz)
                                                      ▼
                               ┌──────────────────────────────────────────────┐
                               │               MultitouchBridge               │
                               │        (Thread-safe C-ABI callback)          │
                               └──────────────────────┬───────────────────────┘
                                                      │ normalized MTTouch frames
                                                      ▼
                               ┌──────────────────────────────────────────────┐
                               │              EdgeGestureEngine               │
                               │  - 4-State FSM (Idle -> Candidate -> Slide)  │
                               │  - Deadzone & Perpendicular cancellation     │
                               │  - Double-tap interval & distance detection  │
                               │  - Cursor Freeze & Haptic tick generation    │
                               └──────────────────────┬───────────────────────┘
                                                      │ EdgeGestureAction
                                                      ▼
                               ┌──────────────────────────────────────────────┐
                               │              EdgeAppCoordinator             │
                               │   (Coordinates hardware, UI, HUD, & status)  │
                               └──────┬───────────────┬───────────────┬───────┘
                                      │               │               │
             ┌────────────────────────┘               │               └────────────────────────┐
             ▼                                        ▼                                        ▼
    ┌─────────────────┐                      ┌─────────────────┐                      ┌─────────────────┐
    │ AudioController │                      │BrightnessManager│                      │  MediaManager   │
    │  (CoreAudio HAL)│                      │(DisplayServices)│                      │ (NX_SYSDEFINED) │
    └────────┬────────┘                      └────────┬────────┘                      └────────┬────────┘
             │                                        │                                        │
             └────────────────────────────────────────┼────────────────────────────────────────┘
                                                      │
                                                      ▼
                                             ┌─────────────────┐
                                             │   HUDManager    │
                                             │(Liquid-Glass OSD)
                                             └─────────────────┘
```

---

## Requirements

- **Operating System:** macOS 13.0 (Ventura) or newer (macOS 14 Sonoma, macOS 15 Sequoia, macOS 26/27 fully supported on Apple Silicon and Intel).
- **Permissions:** Accessibility access (`Privacy & Security -> Accessibility`), required for trackpad edge touch coordinates and cursor lock.

---

## Building and Packaging

### Quick Build & Run (CLI)
```bash
# Build with Swift Package Manager
swift build

# Run the background agent directly
swift run Edge
```

### Build the Standalone `.app` Bundle
Use the included bundling script to produce a release-ready, signed `Edge.app`:
```bash
./scripts/bundle.sh
```
This builds and places `Edge.app` in `build/Edge.app`.

To launch it immediately:
```bash
open build/Edge.app
```

---

## Automated Test Suite

Edge includes an extensive, 4-tier opaque-box test harness with synthetic multitouch frame injectors and hardware controller test doubles:
- **Tier 1:** Baseline Feature Tests (165 tests)
- **Tier 2:** Boundary & Corner Tests (35 tests)
- **Tier 3:** Cross-Feature Combinations & Concurrency Tests (10 tests)
- **Tier 4:** Real-World Usage Scenarios (7 tests)
- **Unit Suites:** Hardware, Preferences, Multitouch Bridge, Geometry, Cursor & Haptics, Status Bar (68 tests)

**Total:** **285 automated tests passing with 100% success rate (0 failures).**

Run the full test suite anytime:
```bash
swift test --no-parallel
```
