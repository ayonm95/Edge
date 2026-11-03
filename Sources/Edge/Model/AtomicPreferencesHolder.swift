// Sources/Edge/Model/AtomicPreferencesHolder.swift
import Foundation
import os

/// Thread-safe atomic container storing the current `PreferencesSnapshot`.
///
/// Designed for high-frequency (120Hz) read access from low-level Multitouch C callbacks
/// with sub-microsecond latency and zero memory allocations.
public final class AtomicPreferencesHolder: @unchecked Sendable {
    /// Shared singleton instance used across the Edge application.
    public static let shared = AtomicPreferencesHolder()

    private let lockPtr: UnsafeMutablePointer<os_unfair_lock_s>
    private var _snapshot: PreferencesSnapshot

    /// Initializes a new atomic holder with an optional initial snapshot.
    /// - Parameter initialSnapshot: Starting configuration snapshot (defaults to `.default`).
    public init(initialSnapshot: PreferencesSnapshot = .default) {
        self.lockPtr = UnsafeMutablePointer<os_unfair_lock_s>.allocate(capacity: 1)
        self.lockPtr.initialize(to: os_unfair_lock_s())
        self._snapshot = initialSnapshot
    }

    deinit {
        lockPtr.deinitialize(count: 1)
        lockPtr.deallocate()
    }

    /// Atomically reads and returns a copy of the current `PreferencesSnapshot`.
    ///
    /// Performance: Executes in ~10-15 nanoseconds under normal uncontended operation.
    /// Thread Safety: Safe to invoke concurrently from any background thread or C callback.
    public func get() -> PreferencesSnapshot {
        os_unfair_lock_lock(lockPtr)
        let snapshot = _snapshot
        os_unfair_lock_unlock(lockPtr)
        return snapshot
    }

    /// Atomically replaces the current snapshot with a new value.
    /// - Parameter snapshot: The updated `PreferencesSnapshot`.
    public func set(_ snapshot: PreferencesSnapshot) {
        os_unfair_lock_lock(lockPtr)
        _snapshot = snapshot
        os_unfair_lock_unlock(lockPtr)
    }

    /// Convenience alias for `set(_:)` to maintain API compatibility.
    public func update(_ snapshot: PreferencesSnapshot) {
        set(snapshot)
    }

    /// Mutates the stored snapshot in-place within the atomic lock boundary.
    /// - Parameter transform: Closure receiving an inout reference to the snapshot.
    public func mutate(_ transform: (inout PreferencesSnapshot) -> Void) {
        os_unfair_lock_lock(lockPtr)
        transform(&_snapshot)
        os_unfair_lock_unlock(lockPtr)
    }
}
