// Tests/EdgeTests/Unit/CursorAndHapticsTests.swift
import Testing
import Foundation
import CoreGraphics
import AppKit
@testable import Edge

@Suite("Cursor & Haptics Unit Tests", .serialized)
struct CursorAndHapticsTests {

    // MARK: - 1. CursorManager Tests

    @Test("CursorManager conforms to CursorControlling")
    func cursorManagerProtocolConformance() {
        let manager: any Edge.CursorControlling = Edge.CursorManager()
        #expect(manager.isFrozen == false)
    }

    @Test("CursorManager freezeCursor updates isFrozen and anchorPoint")
    func cursorManagerFreezeUpdatesState() {
        let manager = Edge.CursorManager()
        defer { manager.reset() }

        let target = CGPoint(x: 150, y: 250)
        manager.freezeCursor(at: target)
        #expect(manager.isFrozen == true)
        #expect(manager.anchorPoint == target)
        #expect(manager.freezeCallCount == 1)

        manager.unfreezeCursor()
        #expect(manager.isFrozen == false)
        #expect(manager.anchorPoint == nil)
        #expect(manager.unfreezeCallCount == 1)
    }

    @Test("CursorManager freeze and unfreeze are strictly idempotent")
    func cursorManagerIdempotency() {
        let manager = Edge.CursorManager()
        defer { manager.reset() }

        // Multiple freeze calls should only increment count once
        manager.freezeCursor(at: CGPoint(x: 100, y: 100))
        manager.freezeCursor(at: CGPoint(x: 120, y: 120))
        manager.freezeCursor(at: CGPoint(x: 140, y: 140))
        #expect(manager.isFrozen == true)
        #expect(manager.freezeCallCount == 1)
        #expect(manager.anchorPoint == CGPoint(x: 140, y: 140))

        // Multiple unfreeze calls should only increment count once
        manager.unfreezeCursor()
        manager.unfreezeCursor()
        manager.unfreezeCursor()
        #expect(manager.isFrozen == false)
        #expect(manager.unfreezeCallCount == 1)
        #expect(manager.anchorPoint == nil)
    }

    @Test("CursorManager handles normalized coordinates without jumping to zero")
    func cursorManagerNormalizedCoordinates() {
        let manager = Edge.CursorManager()
        defer { manager.reset() }

        // Pass normalized coordinates (e.g. 0.95, 0.50 from gesture engine)
        manager.freezeCursor(at: CGPoint(x: 0.95, y: 0.50))
        #expect(manager.isFrozen == true)
        #expect(manager.anchorPoint == CGPoint(x: 0.95, y: 0.50))
        manager.unfreezeCursor()
        #expect(manager.isFrozen == false)
    }

    @Test("CursorManager concurrent freeze and unfreeze stress test")
    func cursorManagerConcurrencyStress() {
        let manager = Edge.CursorManager()
        defer { manager.reset() }

        DispatchQueue.concurrentPerform(iterations: 100) { i in
            if i % 2 == 0 {
                manager.freezeCursor(at: CGPoint(x: CGFloat(i), y: CGFloat(i)))
            } else {
                manager.unfreezeCursor()
            }
        }
        // Must complete without deadlock or memory corruption
        manager.reset()
        #expect(manager.isFrozen == false)
    }

    // MARK: - 2. HapticsManager Tests

    @Test("HapticsManager conforms to HapticsPerforming")
    func hapticsManagerProtocolConformance() {
        let manager: any Edge.HapticsPerforming = Edge.HapticsManager()
        #expect(manager.tickCount == 0)
    }

    @Test("HapticsManager increments tickCount on performTick")
    func hapticsManagerPerformTick() {
        let manager = Edge.HapticsManager(minInterval: 0.0)
        manager.reset()
        #expect(manager.tickCount == 0)

        manager.performTick()
        manager.performTick()
        manager.performTick()
        #expect(manager.tickCount == 3)
        #expect(manager.hardwareTickCount == 3)

        manager.reset()
        #expect(manager.tickCount == 0)
        #expect(manager.hardwareTickCount == 0)
    }

    @Test("HapticsManager throttles hardware ticks with rate limiter")
    func hapticsManagerRateLimiting() {
        // Set a 50ms rate limit
        let manager = Edge.HapticsManager(minInterval: 0.050)
        manager.reset()

        // Call 10 times in rapid succession (< 1ms)
        for _ in 0..<10 {
            manager.performTick()
        }

        // Logical ticks reflect all 10 step requests for test assertions
        #expect(manager.tickCount == 10)
        // Hardware ticks should be throttled to 1 impulse
        #expect(manager.hardwareTickCount == 1)
    }

    @Test("HapticsManager concurrent performTick stress test")
    func hapticsManagerConcurrencyStress() {
        let manager = Edge.HapticsManager(minInterval: 0.0)
        manager.reset()

        DispatchQueue.concurrentPerform(iterations: 500) { _ in
            manager.performTick()
        }

        #expect(manager.tickCount == 500)
    }
}
