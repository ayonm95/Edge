// Sources/Edge/Hardware/AudioController.swift
import Foundation
import CoreAudio
import AudioToolbox

/// Protocol defining the hardware and software audio volume and mute interface.
public protocol AudioControlling: Sendable {
    /// Returns the current master output volume scalar in the range [0.0, 1.0].
    /// Returns 0.0 if the output is currently muted.
    func getVolume() -> Float

    /// Sets the master output volume scalar clamped to [0.0, 1.0].
    /// Setting a non-zero volume while muted un-mutes automatically.
    func setVolume(_ volume: Float)

    /// Returns whether the system output is currently muted.
    func isMuted() -> Bool

    /// Toggles the mute state and returns the new mute state (true if muted, false if unmuted).
    /// Un-muting restores prior non-zero volume, defaulting to safe 0.25 if previous was zero.
    func toggleMute() -> Bool

    /// Registers a listener callback invoked when volume or mute state changes.
    func setVolumeListener(_ listener: @escaping @Sendable (Float, Bool) -> Void)
}

/// Represents an immutable snapshot of system audio state.
public struct AudioState: Sendable, Equatable {
    public let volume: Float
    public let isMuted: Bool
    public let isSettable: Bool
    public let deviceName: String

    public init(volume: Float, isMuted: Bool, isSettable: Bool, deviceName: String) {
        self.volume = volume
        self.isMuted = isMuted
        self.isSettable = isSettable
        self.deviceName = deviceName
    }
}

/// Hardware audio controller integrating directly with macOS CoreAudio HAL C API.
///
/// Features:
/// - Master channel (`kAudioObjectPropertyElementMain`) volume query and set.
/// - Channel 1 & Channel 2 fallback for USB DACs and multi-channel audio interfaces.
/// - Settability validation via `AudioObjectIsPropertySettable`.
/// - Automatic un-mute on upward volume adjustment.
/// - Bidirectional sync with macOS hardware keys, Control Center, and headphone/AirPod disconnects
///   via `AudioObjectAddPropertyListenerBlock`.
/// - Headless/CI resilience with internal software state backing and asynchronous listener race suppression.
public final class AudioController: AudioControlling, @unchecked Sendable {
    public static let shared = AudioController()

    // Global suppression of stale asynchronous HAL listener notifications across all instances
    private static let writeLock = NSLock()
    private static var lastProgrammaticWriteTime: UInt64 = 0
    private static let programmaticSuppressionWindowNanoseconds: UInt64 = 500_000_000 // 500ms

    private static func recordProgrammaticWrite() {
        writeLock.lock()
        lastProgrammaticWriteTime = DispatchTime.now().uptimeNanoseconds
        writeLock.unlock()
    }

    private static func isProgrammaticSuppressed() -> Bool {
        writeLock.lock()
        let lastWrite = lastProgrammaticWriteTime
        writeLock.unlock()
        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = now >= lastWrite ? (now - lastWrite) : 0
        return elapsed < programmaticSuppressionWindowNanoseconds
    }

    private let lock = NSLock()
    private let halQueue = DispatchQueue(label: "com.edge.slider.audiocontroller.hal", qos: .userInteractive)

    private var currentOutputDeviceID: AudioDeviceID = 0
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var muteListenerBlock: AudioObjectPropertyListenerBlock?

    // Cached property addresses used during listener registration to prevent mismatch during teardown
    private var registeredVolumeAddress: AudioObjectPropertyAddress?
    private var registeredMuteAddress: AudioObjectPropertyAddress?

    // Internal state cache for resilience and fallback
    private var cachedVolume: Float = 0.5
    private var cachedMuted: Bool = false
    private var previousVolume: Float = 0.5
    private var volumeListener: (@Sendable (Float, Bool) -> Void)?

    public init() {
        halQueue.sync {
            refreshCurrentDevice()
            setupDefaultDeviceListener()
        }
    }

    deinit {
        teardownListeners()
    }

    // MARK: - AudioControlling Protocol Implementation

    public func getVolume() -> Float {
        lock.lock()
        defer { lock.unlock() }

        if cachedMuted {
            return 0.0
        }

        if AudioController.isProgrammaticSuppressed() {
            return cachedVolume
        }

        let deviceID = currentOutputDeviceID
        guard deviceID != 0 else {
            return cachedVolume
        }

        var volume: Float32 = 0.0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        let element = findVolumeElement(for: deviceID)
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )

        if AudioObjectHasProperty(deviceID, &volAddress) {
            let status = AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &volSize, &volume)
            if status == noErr {
                let clamped = min(max(volume, 0.0), 1.0)
                cachedVolume = clamped
                if clamped > 0.0 {
                    previousVolume = clamped
                }
                return clamped
            }
        }

        return cachedVolume
    }

    public func setVolume(_ volume: Float) {
        let clamped = min(max(volume, 0.0), 1.0)
        var listenerToNotify: (@Sendable (Float, Bool) -> Void)?
        var notifyMuted = false

        AudioController.recordProgrammaticWrite()

        lock.lock()
        self.cachedVolume = clamped
        if clamped > 0.0 {
            self.previousVolume = clamped
        } else {
            self.previousVolume = 0.0
        }

        let deviceID = self.currentOutputDeviceID
        var unmutedTriggered = false

        if clamped > 0.0 && self.cachedMuted {
            self.cachedMuted = false
            unmutedTriggered = true
        }
        notifyMuted = self.cachedMuted
        listenerToNotify = self.volumeListener
        lock.unlock()

        // Asynchronously dispatch hardware HAL write to avoid blocking 120Hz gesture loop
        if deviceID != 0 {
            halQueue.async { [weak self] in
                guard let self = self else { return }
                if unmutedTriggered {
                    self.writeMuteToHardware(deviceID: deviceID, muted: false)
                }
                self.writeVolumeToHardware(deviceID: deviceID, volume: clamped)
            }
        }

        // Notify listener
        listenerToNotify?(clamped, notifyMuted)
    }

    public func isMuted() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if AudioController.isProgrammaticSuppressed() {
            return cachedMuted
        }

        let deviceID = currentOutputDeviceID
        guard deviceID != 0 else {
            return cachedMuted
        }

        var muteVal: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        let element = findMuteElement(for: deviceID)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )

        if AudioObjectHasProperty(deviceID, &muteAddress) {
            let status = AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &muteVal)
            if status == noErr {
                let isMuted = (muteVal != 0)
                cachedMuted = isMuted
                return isMuted
            }
        }

        return cachedMuted
    }

    public func toggleMute() -> Bool {
        var newMuted = false
        var targetVolume: Float = 0.0
        var listenerToNotify: (@Sendable (Float, Bool) -> Void)?
        var deviceID: AudioDeviceID = 0

        AudioController.recordProgrammaticWrite()

        lock.lock()
        deviceID = currentOutputDeviceID
        if cachedMuted {
            // Un-mute: restore previous volume, default to safe 0.25 if previous was 0
            newMuted = false
            cachedMuted = false
            targetVolume = previousVolume > 0.0 ? previousVolume : 0.25
            cachedVolume = targetVolume
        } else {
            // Mute: save current volume
            previousVolume = cachedVolume > 0.0 ? cachedVolume : 0.0
            newMuted = true
            cachedMuted = true
            targetVolume = 0.0
            cachedVolume = 0.0
        }

        listenerToNotify = self.volumeListener
        lock.unlock()

        // Asynchronously dispatch hardware HAL write to avoid blocking callers
        if deviceID != 0 {
            halQueue.async { [weak self] in
                guard let self = self else { return }
                self.writeMuteToHardware(deviceID: deviceID, muted: newMuted)
                if !newMuted {
                    self.writeVolumeToHardware(deviceID: deviceID, volume: targetVolume)
                }
            }
        }

        listenerToNotify?(targetVolume, newMuted)

        return newMuted
    }

    public func setVolumeListener(_ listener: @escaping @Sendable (Float, Bool) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        self.volumeListener = listener
    }

    public func removeVolumeListener() {
        lock.lock()
        defer { lock.unlock() }
        self.volumeListener = nil
    }

    // MARK: - Helper Methods

    /// Adjusts volume by a relative delta.
    public func adjustVolume(delta: Float) {
        let current = getVolume()
        setVolume(current + delta)
    }

    /// Steps volume up or down in discrete increments (standard 1/16th or fine 1/64th).
    public func stepVolume(up: Bool, fine: Bool = false) {
        let step: Float = fine ? (1.0 / 64.0) : (1.0 / 16.0)
        adjustVolume(delta: up ? step : -step)
    }

    /// Returns detailed audio hardware state including device name and settability.
    public func getAudioState() -> AudioState {
        lock.lock()
        defer { lock.unlock() }

        let deviceID = currentOutputDeviceID
        guard deviceID != 0 else {
            return AudioState(volume: cachedVolume, isMuted: cachedMuted, isSettable: true, deviceName: "Default Output")
        }

        let element = findVolumeElement(for: deviceID)
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        var isSettable: DarwinBoolean = false
        AudioObjectIsPropertySettable(deviceID, &volAddress, &isSettable)

        var name = "Output Audio"
        var unmanagedName: Unmanaged<CFString>?
        var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &unmanagedName) == noErr,
           let cfName = unmanagedName?.takeRetainedValue() {
            name = cfName as String
        }

        return AudioState(volume: cachedVolume, isMuted: cachedMuted, isSettable: isSettable.boolValue, deviceName: name)
    }

    // MARK: - Private CoreAudio Helpers

    private func findVolumeElement(for deviceID: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &address) {
            return kAudioObjectPropertyElementMain
        }
        return 1 // Fallback to Channel 1 (Left)
    }

    private func findMuteElement(for deviceID: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &address) {
            return kAudioObjectPropertyElementMain
        }
        return 1
    }

    private func writeMuteToHardware(deviceID: AudioDeviceID, muted: Bool) {
        let element = findMuteElement(for: deviceID)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        var isSettable: DarwinBoolean = false
        AudioObjectIsPropertySettable(deviceID, &muteAddress, &isSettable)
        guard isSettable.boolValue else { return }

        var newMuteVal: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, size, &newMuteVal)

        if element != kAudioObjectPropertyElementMain {
            var ch2Address = muteAddress
            ch2Address.mElement = 2
            if AudioObjectHasProperty(deviceID, &ch2Address) {
                var ch2Settable: DarwinBoolean = false
                AudioObjectIsPropertySettable(deviceID, &ch2Address, &ch2Settable)
                if ch2Settable.boolValue {
                    AudioObjectSetPropertyData(deviceID, &ch2Address, 0, nil, size, &newMuteVal)
                }
            }
        }
    }

    private func writeVolumeToHardware(deviceID: AudioDeviceID, volume: Float) {
        let element = findVolumeElement(for: deviceID)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        var isSettable: DarwinBoolean = false
        AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
        guard isSettable.boolValue else { return }

        var vol = volume
        let size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)

        if element != kAudioObjectPropertyElementMain {
            var ch2Address = address
            ch2Address.mElement = 2
            if AudioObjectHasProperty(deviceID, &ch2Address) {
                var ch2Settable: DarwinBoolean = false
                AudioObjectIsPropertySettable(deviceID, &ch2Address, &ch2Settable)
                if ch2Settable.boolValue {
                    AudioObjectSetPropertyData(deviceID, &ch2Address, 0, nil, size, &vol)
                }
            }
        }
    }

    private func refreshCurrentDevice() {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )

        lock.lock()
        let oldDeviceID = self.currentOutputDeviceID
        if status == noErr && deviceID != 0 {
            self.currentOutputDeviceID = deviceID
        }
        lock.unlock()

        if status == noErr && deviceID != oldDeviceID && deviceID != 0 {
            teardownDeviceListeners(for: oldDeviceID)
            setupDeviceListeners(for: deviceID)
            syncFromHardware(deviceID: deviceID, force: true)
        }
    }

    private func syncFromHardware(deviceID: AudioDeviceID, force: Bool = false) {
        guard deviceID != 0 else { return }

        if !force && AudioController.isProgrammaticSuppressed() {
            return
        }

        var volume: Float32 = 0.0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        let volElement = findVolumeElement(for: deviceID)
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: volElement
        )
        if AudioObjectHasProperty(deviceID, &volAddress) {
            if AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &volSize, &volume) == noErr {
                lock.lock()
                cachedVolume = min(max(volume, 0.0), 1.0)
                if cachedVolume > 0.0 {
                    previousVolume = cachedVolume
                }
                lock.unlock()
            }
        }

        var muteVal: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        let muteElement = findMuteElement(for: deviceID)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: muteElement
        )
        if AudioObjectHasProperty(deviceID, &muteAddress) {
            if AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &muteVal) == noErr {
                lock.lock()
                cachedMuted = (muteVal != 0)
                lock.unlock()
            }
        }

        lock.lock()
        let curVol = cachedMuted ? 0.0 : cachedVolume
        let curMuted = cachedMuted
        let listener = self.volumeListener
        lock.unlock()

        listener?(curVol, curMuted)
    }

    private func setupDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.halQueue.async {
                self?.refreshCurrentDevice()
            }
        }
        self.defaultDeviceListenerBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            halQueue,
            block
        )
    }

    private func setupDeviceListeners(for deviceID: AudioDeviceID) {
        guard deviceID != 0 else { return }

        // Volume listener
        let volElement = findVolumeElement(for: deviceID)
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: volElement
        )
        let volBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.syncFromHardware(deviceID: deviceID)
        }
        self.volumeListenerBlock = volBlock
        self.registeredVolumeAddress = volAddress
        AudioObjectAddPropertyListenerBlock(deviceID, &volAddress, halQueue, volBlock)

        // Mute listener
        let muteElement = findMuteElement(for: deviceID)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: muteElement
        )
        let muteBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.syncFromHardware(deviceID: deviceID)
        }
        self.muteListenerBlock = muteBlock
        self.registeredMuteAddress = muteAddress
        AudioObjectAddPropertyListenerBlock(deviceID, &muteAddress, halQueue, muteBlock)
    }

    private func teardownDeviceListeners(for deviceID: AudioDeviceID) {
        guard deviceID != 0 else { return }
        if let block = volumeListenerBlock, var volAddress = registeredVolumeAddress {
            AudioObjectRemovePropertyListenerBlock(deviceID, &volAddress, halQueue, block)
            volumeListenerBlock = nil
            registeredVolumeAddress = nil
        }
        if let block = muteListenerBlock, var muteAddress = registeredMuteAddress {
            AudioObjectRemovePropertyListenerBlock(deviceID, &muteAddress, halQueue, block)
            muteListenerBlock = nil
            registeredMuteAddress = nil
        }
    }

    private func teardownListeners() {
        if let block = defaultDeviceListenerBlock {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, halQueue, block)
            defaultDeviceListenerBlock = nil
        }
        lock.lock()
        let devID = currentOutputDeviceID
        lock.unlock()
        teardownDeviceListeners(for: devID)
    }
}
