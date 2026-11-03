// Tests/EdgeTests/Unit/MultitouchBridgeTests.swift
import Testing
import Foundation
@testable import Edge

@Suite("Multitouch Subsystem & Bridge Unit Tests", .serialized)
struct MultitouchBridgeTests {

    @Test("MTTouch C struct layout matches exact 96-byte memory specifications")
    func testMTTouchMemoryLayout() {
        #expect(MemoryLayout<Edge.MTTouch>.size == 96, "MTTouch struct size must be exactly 96 bytes")
        #expect(MemoryLayout<Edge.MTTouch>.stride == 96, "MTTouch struct stride must be exactly 96 bytes")
        #expect(MemoryLayout<Edge.MTTouch>.alignment == 8, "MTTouch struct alignment must be 8 bytes due to timestamp Double")

        #expect(MemoryLayout<Edge.MTPoint>.size == 8, "MTPoint size must be 8 bytes (two 32-bit floats)")
        #expect(MemoryLayout<Edge.MTPoint>.stride == 8, "MTPoint stride must be 8 bytes")

        #expect(MemoryLayout<Edge.MTVector>.size == 16, "MTVector size must be 16 bytes (two MTPoints)")
        #expect(MemoryLayout<Edge.MTVector>.stride == 16, "MTVector stride must be 16 bytes")
    }

    @Test("TouchPhase enum mapping and state queries")
    func testTouchPhaseMapping() {
        #expect(Edge.TouchPhase.notTracking.rawValue == 0)
        #expect(Edge.TouchPhase.startInRange.rawValue == 1)
        #expect(Edge.TouchPhase.hoverInRange.rawValue == 2)
        #expect(Edge.TouchPhase.makeTouch.rawValue == 3)
        #expect(Edge.TouchPhase.touching.rawValue == 4)
        #expect(Edge.TouchPhase.breakTouch.rawValue == 5)
        #expect(Edge.TouchPhase.lingerInRange.rawValue == 6)
        #expect(Edge.TouchPhase.outOfRange.rawValue == 7)

        #expect(Edge.TouchPhase.makeTouch.isActiveContact == true)
        #expect(Edge.TouchPhase.touching.isActiveContact == true)
        #expect(Edge.TouchPhase.breakTouch.isActiveContact == false)
        #expect(Edge.TouchPhase.notTracking.isActiveContact == false)

        #expect(Edge.TouchPhase.breakTouch.isLifted == true)
        #expect(Edge.TouchPhase.notTracking.isLifted == true)
        #expect(Edge.TouchPhase.outOfRange.isLifted == true)
        #expect(Edge.TouchPhase.touching.isLifted == false)
    }

    @Test("MTTouch memberwise convenience properties")
    func testMTTouchConvenienceProperties() {
        var touch = Edge.MTTouch.makeSynthetic(
            fingerID: 42,
            x: 0.08,
            y: 0.50,
            phase: .touching,
            timestamp: 123.456,
            majorAxis: 8.0,
            minorAxis: 6.0,
            zTotal: 0.75
        )

        #expect(touch.fingerID == 42)
        #expect(touch.position.x == 0.08)
        #expect(touch.position.y == 0.50)
        #expect(touch.phase == .touching)
        #expect(touch.timestamp == 123.456)
        #expect(touch.majorAxis == 8.0)
        #expect(touch.minorAxis == 6.0)
        #expect(touch.majorRadius == 8.0)
        #expect(touch.minorRadius == 6.0)
        #expect(touch.zTotal == 0.75)

        // Mutating position via convenience property
        touch.position = Edge.MTPoint(x: 0.09, y: 0.52)
        #expect(touch.normalizedVector.position.x == 0.09)
        #expect(touch.normalizedVector.position.y == 0.52)

        // Mutating phase
        touch.phase = .breakTouch
        #expect(touch.state == Edge.TouchPhase.breakTouch.rawValue)
    }

    @Test("MultitouchBridge lifecycle start, stop, and clean teardown")
    func testBridgeLifecycle() throws {
        let bridge = Edge.MultitouchBridge()
        #expect(bridge.isRunning == false)

        try bridge.start()
        #expect(bridge.isRunning == true)

        bridge.stop()
        #expect(bridge.isRunning == false)
    }

    final class SpyBridgeDelegate: Edge.MultitouchBridgeDelegate, @unchecked Sendable {
        private let lock = NSLock()
        var receivedBatches: [[Edge.MTTouch]] = []
        var receivedKinds: [Edge.MultitouchDeviceKind] = []

        func multitouchBridge(
            _ bridge: any Edge.MultitouchBridging,
            didReceiveTouches touches: [Edge.MTTouch],
            deviceKind: Edge.MultitouchDeviceKind,
            isBuiltIn: Bool,
            timestamp: Double,
            frame: Int32
        ) {
            lock.lock()
            defer { lock.unlock() }
            receivedBatches.append(touches)
            receivedKinds.append(deviceKind)
        }

        var callCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return receivedBatches.count
        }
    }

    @Test("MultitouchBridge simulated frame injection propagates to delegate")
    func testSimulatedFrameInjection() throws {
        let bridge = Edge.MultitouchBridge()
        let spy = SpyBridgeDelegate()
        bridge.setDelegate(spy)

        try bridge.start(enableHardware: false)

        let touch1 = Edge.MTTouch.makeSynthetic(fingerID: 1, x: 0.05, y: 0.3)
        let touch2 = Edge.MTTouch.makeSynthetic(fingerID: 2, x: 0.95, y: 0.7)

        bridge.simulateFrame(
            touches: [touch1, touch2],
            isBuiltIn: true,
            deviceKind: .builtInTrackpad,
            timestamp: 200.0,
            frame: 10
        )

        #expect(spy.callCount == 1)
        #expect(spy.receivedBatches.first?.count == 2)
        #expect(spy.receivedBatches.first?[0].fingerID == 1)
        #expect(spy.receivedBatches.first?[1].fingerID == 2)
        #expect(spy.receivedKinds.first == .builtInTrackpad)

        bridge.stop()
    }

    @Test("MultitouchBridge filters Magic Mouse based on preferences")
    func testMagicMouseFiltering() throws {
        let prefsHolder = Edge.AtomicPreferencesHolder(initialSnapshot: Edge.PreferencesSnapshot(enableMagicMouse: false))
        let bridge = Edge.MultitouchBridge(preferencesHolder: prefsHolder)
        let spy = SpyBridgeDelegate()
        bridge.setDelegate(spy)

        try bridge.start(enableHardware: false)

        let mouseTouch = Edge.MTTouch.makeSynthetic(fingerID: 1, x: 0.05, y: 0.5)

        // 1. With enableMagicMouse = false, simulated Magic Mouse frames should be suppressed
        bridge.simulateFrame(
            touches: [mouseTouch],
            isBuiltIn: false,
            deviceKind: .magicMouse,
            timestamp: 300.0,
            frame: 1
        )
        #expect(spy.callCount == 0, "Magic Mouse frames should be filtered out when enableMagicMouse is false")

        // 2. Enable Magic Mouse dynamically
        var updatedPrefs = prefsHolder.get()
        updatedPrefs.enableMagicMouse = true
        prefsHolder.set(updatedPrefs)

        bridge.simulateFrame(
            touches: [mouseTouch],
            isBuiltIn: false,
            deviceKind: .magicMouse,
            timestamp: 300.05,
            frame: 2
        )
        #expect(spy.callCount == 1, "Magic Mouse frames should be processed when enableMagicMouse is true")

        bridge.stop()
    }

    @Test("MockMultitouchBridge records state transitions and injected frames")
    func testMockBridge() throws {
        let mock = Edge.MockMultitouchBridge()
        let spy = SpyBridgeDelegate()
        mock.setDelegate(spy)

        #expect(mock.isRunning == false)
        try mock.start()
        #expect(mock.isRunning == true)
        #expect(mock.startCallCount == 1)

        mock.simulateFrame(
            touches: [Edge.MTTouch.makeSynthetic(fingerID: 99, x: 0.5, y: 0.5)],
            isBuiltIn: true,
            deviceKind: .builtInTrackpad
        )

        #expect(mock.injectedFrames.count == 1)
        #expect(spy.callCount == 1)

        mock.stop()
        #expect(mock.isRunning == false)
        #expect(mock.stopCallCount == 1)
    }
}
