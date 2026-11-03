// Tests/EdgeTests/Unit/PreferencesTests.swift
import Testing
import Foundation
@testable import Edge

@Suite("Preferences Unit Tests")
struct PreferencesTests {

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "com.edge.slider.tests.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func cleanupDefaults(suiteName: String) {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    // MARK: - 1. Default Values Verification

    @Test("Default values match canonical specifications")
    func defaultValues() {
        let snapshot = Edge.PreferencesSnapshot.default

        #expect(snapshot.isEnabled)
        #expect(!snapshot.swapSides)
        #expect(abs(snapshot.edgeWidth - 0.08) < 0.0001)
        #expect(abs(snapshot.sensitivity - 1.0) < 0.0001)
        #expect(snapshot.activeArea == Edge.ActiveAreaZone.entire)
        #expect(!snapshot.reverseMediaSwipe)
        #expect(!snapshot.preciseSliding)
        #expect(!snapshot.enableMagicMouse)
        #expect(snapshot.showOSD)
        #expect(snapshot.enableHaptics)
        #expect(snapshot.showMenuBarIcon)

        // Compatibility aliases
        #expect(abs(snapshot.edgeWidthFraction - 0.08) < 0.0001)
        #expect(abs(snapshot.sensitivityMultiplier - 1.0) < 0.0001)
        #expect(!snapshot.magicMouseEnabled)
        #expect(snapshot.showOSDHUD)
        #expect(snapshot.hapticFeedbackEnabled)
    }

    // MARK: - 2. Value Clamping Tests

    @Test("Clamping edge width boundaries")
    func clampingEdgeWidth() {
        // Below lower bound (0.03)
        let tooNarrow = Edge.PreferencesSnapshot(edgeWidth: 0.01)
        #expect(abs(tooNarrow.edgeWidth - 0.03) < 0.0001)

        let negativeWidth = Edge.PreferencesSnapshot(edgeWidth: -1.5)
        #expect(abs(negativeWidth.edgeWidth - 0.03) < 0.0001)

        // Above upper bound (0.20)
        let tooWide = Edge.PreferencesSnapshot(edgeWidth: 0.35)
        #expect(abs(tooWide.edgeWidth - 0.20) < 0.0001)

        let extremeWidth = Edge.PreferencesSnapshot(edgeWidth: 100.0)
        #expect(abs(extremeWidth.edgeWidth - 0.20) < 0.0001)

        // Valid values
        let validWidth = Edge.PreferencesSnapshot(edgeWidth: 0.12)
        #expect(abs(validWidth.edgeWidth - 0.12) < 0.0001)
    }

    @Test("Clamping sensitivity boundaries")
    func clampingSensitivity() {
        // Below lower bound (0.5)
        let tooLow = Edge.PreferencesSnapshot(sensitivity: 0.1)
        #expect(abs(tooLow.sensitivity - 0.5) < 0.0001)

        let zeroSens = Edge.PreferencesSnapshot(sensitivity: 0.0)
        #expect(abs(zeroSens.sensitivity - 0.5) < 0.0001)

        // Above upper bound (2.5)
        let tooHigh = Edge.PreferencesSnapshot(sensitivity: 3.5)
        #expect(abs(tooHigh.sensitivity - 2.5) < 0.0001)

        let extremeSens = Edge.PreferencesSnapshot(sensitivity: 50.0)
        #expect(abs(extremeSens.sensitivity - 2.5) < 0.0001)

        // Valid values
        let validSens = Edge.PreferencesSnapshot(sensitivity: 1.8)
        #expect(abs(validSens.sensitivity - 1.8) < 0.0001)
    }

    // MARK: - 3. Active Area Zone Geometry Tests

    @Test("Active area zone boundaries")
    func activeAreaZoneBoundaries() {
        // Entire edge (maxY = 1.0)
        let entire = Edge.ActiveAreaZone.entire
        #expect(abs(entire.maxY - 1.0) < 0.0001)
        #expect(entire.contains(normalizedY: 0.0))
        #expect(entire.contains(normalizedY: 0.5))
        #expect(entire.contains(normalizedY: 1.0))
        #expect(!entire.contains(normalizedY: -0.01))
        #expect(!entire.contains(normalizedY: 1.01))

        // Bottom 3/4 (maxY = 0.75)
        let threeQuarters = Edge.ActiveAreaZone.bottomThreeQuarters
        #expect(abs(threeQuarters.maxY - 0.75) < 0.0001)
        #expect(threeQuarters.contains(normalizedY: 0.0))
        #expect(threeQuarters.contains(normalizedY: 0.75))
        #expect(!threeQuarters.contains(normalizedY: 0.76))
        #expect(!threeQuarters.contains(normalizedY: 1.0))

        // Bottom Half (maxY = 0.50)
        let half = Edge.ActiveAreaZone.bottomHalf
        #expect(abs(half.maxY - 0.50) < 0.0001)
        #expect(half.contains(normalizedY: 0.0))
        #expect(half.contains(normalizedY: 0.50))
        #expect(!half.contains(normalizedY: 0.51))
        #expect(!half.contains(normalizedY: 0.9))

        // Bottom Quarter (maxY = 0.25)
        let quarter = Edge.ActiveAreaZone.bottomQuarter
        #expect(abs(quarter.maxY - 0.25) < 0.0001)
        #expect(quarter.contains(normalizedY: 0.0))
        #expect(quarter.contains(normalizedY: 0.25))
        #expect(!quarter.contains(normalizedY: 0.26))
        #expect(!quarter.contains(normalizedY: 0.5))
    }

    // MARK: - 4. Codable Round-Trip & Resilience

    @Test("Codable round trip fidelity")
    func codableRoundTrip() throws {
        let original = Edge.PreferencesSnapshot(
            isEnabled: false,
            swapSides: true,
            edgeWidth: 0.15,
            sensitivity: 2.1,
            activeArea: .bottomHalf,
            reverseMediaSwipe: true,
            preciseSliding: true,
            enableMagicMouse: true,
            showOSD: false,
            enableHaptics: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Edge.PreferencesSnapshot.self, from: data)

        #expect(original == decoded)
    }

    @Test("Codable resilience and clamping on corrupted input")
    func codableResilienceAndClamping() throws {
        // Corrupted JSON with out-of-range floats, unknown enum, and missing keys
        let corruptedJson = """
        {
            "edgeWidth": 0.99,
            "sensitivity": -10.0,
            "activeArea": "non_existent_zone"
        }
        """
        let data = corruptedJson.data(using: .utf8)!

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Edge.PreferencesSnapshot.self, from: data)

        // Clamping should have restricted out-of-range values
        #expect(abs(decoded.edgeWidth - 0.20) < 0.0001)
        #expect(abs(decoded.sensitivity - 0.5) < 0.0001)

        // Unknown enum should fall back safely to default .entire
        #expect(decoded.activeArea == .entire)

        // Missing keys should receive canonical defaults
        #expect(decoded.isEnabled)
        #expect(!decoded.swapSides)
        #expect(decoded.showOSD)
        #expect(decoded.enableHaptics)
    }

    // MARK: - 5. AtomicPreferencesHolder Concurrency & High-Frequency Scrubbing

    @Test("Atomic holder basic get and set")
    func atomicHolderBasicGetSet() {
        let initial = Edge.PreferencesSnapshot(swapSides: false, edgeWidth: 0.08)
        let holder = Edge.AtomicPreferencesHolder(initialSnapshot: initial)

        #expect(!holder.get().swapSides)
        #expect(abs(holder.get().edgeWidth - 0.08) < 0.0001)

        let updated = Edge.PreferencesSnapshot(swapSides: true, edgeWidth: 0.14)
        holder.set(updated)

        #expect(holder.get().swapSides)
        #expect(abs(holder.get().edgeWidth - 0.14) < 0.0001)

        // Test in-place mutation
        holder.mutate { snapshot in
            snapshot.sensitivity = 2.2
        }
        #expect(abs(holder.get().sensitivity - 2.2) < 0.0001)
    }

    @Test("Atomic holder high frequency scrubbing")
    func atomicHolderHighFrequencyScrubbing() async {
        let holder = Edge.AtomicPreferencesHolder(initialSnapshot: .default)
        let iterationsPerThread = 2_000
        let threadCount = 8

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<threadCount {
                group.addTask {
                    for _ in 0..<iterationsPerThread {
                        let snapshot = holder.get()
                        #expect(snapshot.edgeWidth >= 0.03)
                        #expect(snapshot.edgeWidth <= 0.20)
                    }
                }
            }
        }
    }

    @Test("Atomic holder concurrent read write stress")
    func atomicHolderConcurrentReadWriteStress() async {
        let holder = Edge.AtomicPreferencesHolder(initialSnapshot: .default)
        let readerCount = 12
        let writerCount = 4
        let readIterations = 2_500
        let writeIterations = 500

        await withTaskGroup(of: Void.self) { group in
            for writerId in 0..<writerCount {
                group.addTask {
                    for i in 0..<writeIterations {
                        let newWidth = 0.03 + Double((writerId + i) % 17) * 0.01
                        let newSens = 0.5 + Double((writerId + i) % 20) * 0.1
                        let snapshot = Edge.PreferencesSnapshot(
                            swapSides: (i % 2 == 0),
                            edgeWidth: newWidth,
                            sensitivity: newSens,
                            activeArea: (i % 2 == 0) ? .entire : .bottomHalf
                        )
                        holder.set(snapshot)
                    }
                }
            }

            for _ in 0..<readerCount {
                group.addTask {
                    for _ in 0..<readIterations {
                        let snapshot = holder.get()
                        #expect(snapshot.edgeWidth >= 0.03)
                        #expect(snapshot.edgeWidth <= 0.20)
                        #expect(snapshot.sensitivity >= 0.5)
                        #expect(snapshot.sensitivity <= 2.5)
                    }
                }
            }
        }
    }

    // MARK: - 6. Preferences Model & UserDefaults Synchronization

    @Test("Preferences user defaults synchronization")
    @MainActor
    func preferencesUserDefaultsSync() {
        let (testDefaults, suiteName) = makeIsolatedDefaults()
        defer { cleanupDefaults(suiteName: suiteName) }

        let holder = Edge.AtomicPreferencesHolder(initialSnapshot: .default)
        let prefs = Edge.Preferences(defaults: testDefaults, holder: holder)

        // Change values via observable model
        prefs.swapSides = true
        prefs.edgeWidth = 0.16
        prefs.sensitivity = 2.2
        prefs.activeArea = .bottomHalf
        prefs.reverseMediaSwipe = true
        prefs.preciseSliding = true
        prefs.enableMagicMouse = true
        prefs.showOSD = false
        prefs.enableHaptics = false
        prefs.showMenuBarIcon = false

        // 1. Verify UserDefaults persistence
        #expect(testDefaults.bool(forKey: Edge.Preferences.Keys.swapSides) == true)
        #expect(abs(testDefaults.double(forKey: Edge.Preferences.Keys.edgeWidth) - 0.16) < 0.0001)
        #expect(abs(testDefaults.double(forKey: Edge.Preferences.Keys.sensitivity) - 2.2) < 0.0001)
        #expect(testDefaults.string(forKey: Edge.Preferences.Keys.activeArea) == Edge.ActiveAreaZone.bottomHalf.rawValue)
        #expect(testDefaults.bool(forKey: Edge.Preferences.Keys.reverseMediaSwipe) == true)
        #expect(testDefaults.bool(forKey: Edge.Preferences.Keys.preciseSliding) == true)
        #expect(testDefaults.bool(forKey: Edge.Preferences.Keys.enableMagicMouse) == true)
        #expect(testDefaults.bool(forKey: Edge.Preferences.Keys.showOSD) == false)
        #expect(testDefaults.bool(forKey: Edge.Preferences.Keys.enableHaptics) == false)
        #expect(testDefaults.bool(forKey: Edge.Preferences.Keys.showMenuBarIcon) == false)

        // 2. Verify Atomic snapshot synchronization
        let snapshot = holder.get()
        #expect(snapshot.swapSides == true)
        #expect(abs(snapshot.edgeWidth - 0.16) < 0.0001)
        #expect(abs(snapshot.sensitivity - 2.2) < 0.0001)
        #expect(snapshot.activeArea == Edge.ActiveAreaZone.bottomHalf)
        #expect(snapshot.reverseMediaSwipe == true)
        #expect(snapshot.preciseSliding == true)
        #expect(snapshot.enableMagicMouse == true)
        #expect(snapshot.showOSD == false)
        #expect(snapshot.enableHaptics == false)
        #expect(snapshot.showMenuBarIcon == false)
    }

    @Test("Preferences clamping on property setters")
    @MainActor
    func preferencesClampingOnPropertySetters() {
        let (testDefaults, suiteName) = makeIsolatedDefaults()
        defer { cleanupDefaults(suiteName: suiteName) }

        let holder = Edge.AtomicPreferencesHolder(initialSnapshot: .default)
        let prefs = Edge.Preferences(defaults: testDefaults, holder: holder)

        // Setting out-of-range edge width
        prefs.edgeWidth = 0.01
        #expect(abs(prefs.edgeWidth - 0.03) < 0.0001)
        #expect(abs(holder.get().edgeWidth - 0.03) < 0.0001)

        prefs.edgeWidth = 0.45
        #expect(abs(prefs.edgeWidth - 0.20) < 0.0001)
        #expect(abs(holder.get().edgeWidth - 0.20) < 0.0001)

        // Setting out-of-range sensitivity
        prefs.sensitivity = 0.2
        #expect(abs(prefs.sensitivity - 0.5) < 0.0001)
        #expect(abs(holder.get().sensitivity - 0.5) < 0.0001)

        prefs.sensitivity = 10.0
        #expect(abs(prefs.sensitivity - 2.5) < 0.0001)
        #expect(abs(holder.get().sensitivity - 2.5) < 0.0001)
    }

    @Test("Preferences reset to defaults")
    @MainActor
    func preferencesResetToDefaults() {
        let (testDefaults, suiteName) = makeIsolatedDefaults()
        defer { cleanupDefaults(suiteName: suiteName) }

        let holder = Edge.AtomicPreferencesHolder(initialSnapshot: .default)
        let prefs = Edge.Preferences(defaults: testDefaults, holder: holder)

        // Set non-default values
        prefs.swapSides = true
        prefs.edgeWidth = 0.18
        prefs.sensitivity = 2.4
        prefs.activeArea = .bottomQuarter

        // Reset
        prefs.resetToDefaults()

        // Verify restoration
        #expect(!prefs.swapSides)
        #expect(abs(prefs.edgeWidth - 0.08) < 0.0001)
        #expect(abs(prefs.sensitivity - 1.0) < 0.0001)
        #expect(prefs.activeArea == Edge.ActiveAreaZone.entire)
        #expect(holder.get() == Edge.PreferencesSnapshot.default)
    }
}
