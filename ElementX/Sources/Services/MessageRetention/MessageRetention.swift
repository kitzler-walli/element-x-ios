//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// The room's retention combined with the server's configuration.
nonisolated struct RoomMessageRetention: Equatable, Sendable {
    let policy: RoomRetentionPolicy
    let configuration: RetentionServerConfiguration
    
    /// How long messages are kept, or `nil` when they are kept forever.
    var effectiveMaxLifetime: TimeInterval? {
        guard let maxLifetime = policy.maxLifetime ?? configuration.defaultMaxLifetime else { return nil }
        return configuration.limits.clamped(maxLifetime)
    }
    
    /// Whether the room has a value that the server's limits don't allow.
    var isOutOfLimits: Bool {
        guard let maxLifetime = policy.maxLifetime else { return false }
        return !configuration.limits.contains(maxLifetime)
    }
}

/// The `m.room.retention` state of a room, in whole seconds.
nonisolated struct RoomRetentionPolicy: Equatable, Sendable {
    static let unset = RoomRetentionPolicy(maxLifetime: nil)
    
    /// The values the app reads and writes, from 1 second to 100 years.
    static let acceptedRange: ClosedRange<TimeInterval> = 1...(100 * 365 * 24 * 60 * 60)
    
    /// `nil` when the room has no value of its own.
    let maxLifetime: TimeInterval?
    
    /// The event content to send for this policy.
    var contentJSON: String {
        guard let maxLifetime else { return "{}" }
        return #"{"max_lifetime":\#(Int(maxLifetime) * 1000)}"#
    }
    
    /// Rounds to whole seconds and keeps the value within ``acceptedRange``.
    init(maxLifetime: TimeInterval?) {
        guard let maxLifetime, maxLifetime.isFinite else {
            self.maxLifetime = nil
            return
        }
        
        self.maxLifetime = min(max(maxLifetime.rounded(), Self.acceptedRange.lowerBound), Self.acceptedRange.upperBound)
    }
    
    /// Reads the `m.room.retention` event content, ignoring anything that isn't a valid `max_lifetime`.
    init(contentJSON: String) {
        guard let content = try? JSONDecoder().decode(Content.self, from: Data(contentJSON.utf8)),
              let milliseconds = content.maxLifetime,
              milliseconds > 0,
              TimeInterval(milliseconds) / 1000 <= Self.acceptedRange.upperBound else {
            self.init(maxLifetime: nil)
            return
        }
        
        self.init(maxLifetime: TimeInterval(milliseconds) / 1000)
    }
    
    /// Decoding (rather than casting) rejects booleans and strings for `max_lifetime`.
    private struct Content: Decodable {
        let maxLifetime: Int?
        
        enum CodingKeys: String, CodingKey {
            case maxLifetime = "max_lifetime"
        }
    }
}

/// The homeserver's retention configuration, in seconds.
nonisolated struct RetentionServerConfiguration: Equatable, Sendable {
    var isEnabled: Bool
    var defaultMaxLifetime: TimeInterval?
    var limits: RetentionLimits
}

/// The range of retention values allowed by the server, each bound optional.
nonisolated struct RetentionLimits: Equatable, Sendable {
    static let unlimited = RetentionLimits(lower: nil, upper: nil)
    
    var lower: TimeInterval?
    var upper: TimeInterval?
    
    func contains(_ value: TimeInterval) -> Bool {
        value >= (lower ?? -.infinity) && value <= (upper ?? .infinity)
    }
    
    func clamped(_ value: TimeInterval) -> TimeInterval {
        min(max(value, lower ?? -.infinity), upper ?? .infinity)
    }
}
