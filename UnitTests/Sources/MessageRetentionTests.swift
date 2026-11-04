//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

struct MessageRetentionTests {
    @Test("Room state content is parsed in whole seconds")
    func parseContent() {
        #expect(RoomRetentionPolicy(contentJSON: #"{"max_lifetime":86400000}"#).maxLifetime == 86400)
        #expect(RoomRetentionPolicy(contentJSON: #"{"max_lifetime":86400001}"#).maxLifetime == 86400)
        #expect(RoomRetentionPolicy(contentJSON: #"{"max_lifetime":86400000,"min_lifetime":1000,"foo":"bar"}"#).maxLifetime == 86400)
        #expect(RoomRetentionPolicy(contentJSON: #"{"max_lifetime":3153600000000}"#).maxLifetime == 3_153_600_000)
        #expect(RoomRetentionPolicy(contentJSON: #"{}"#).maxLifetime == nil)
        #expect(RoomRetentionPolicy(contentJSON: #"{"min_lifetime":1000}"#).maxLifetime == nil)
    }
    
    @Test("Odd room state content never crashes and means no room value",
          arguments: ["",
                      "not json",
                      "[]",
                      "null",
                      #"{"max_lifetime":true}"#,
                      #"{"max_lifetime":"10"}"#,
                      #"{"max_lifetime":-5}"#,
                      #"{"max_lifetime":0}"#,
                      #"{"max_lifetime":1e30}"#,
                      #"{"max_lifetime":3153600000001}"#])
    func parseOddContent(contentJSON: String) {
        #expect(RoomRetentionPolicy(contentJSON: contentJSON).maxLifetime == nil)
    }
    
    @Test("Content is written in milliseconds and cleared as an empty object")
    func writeContent() {
        #expect(RoomRetentionPolicy(maxLifetime: 3600).contentJSON == #"{"max_lifetime":3600000}"#)
        #expect(RoomRetentionPolicy.unset.contentJSON == "{}")
    }
    
    @Test("A written policy reads back as the same value", arguments: [60.0, 33.days, 728.days])
    func roundTrip(maxLifetime: TimeInterval) {
        let policy = RoomRetentionPolicy(maxLifetime: maxLifetime)
        #expect(RoomRetentionPolicy(contentJSON: policy.contentJSON) == policy)
    }
    
    @Test("Values outside the accepted range are kept within it")
    func acceptedRange() {
        #expect(RoomRetentionPolicy(maxLifetime: 0.4).maxLifetime == 1)
        #expect(RoomRetentionPolicy(maxLifetime: 200 * 365.days).maxLifetime == 100 * 365.days)
        #expect(RoomRetentionPolicy(maxLifetime: .infinity).maxLifetime == nil)
    }
    
    @Test("Effective retention follows the room value, the server default, then nothing",
          arguments: [EffectiveRetentionCase(room: 30.days, serverDefault: 90.days, limits: .unlimited, effective: 30.days, isOutOfLimits: false),
                      EffectiveRetentionCase(room: nil, serverDefault: 90.days, limits: .unlimited, effective: 90.days, isOutOfLimits: false),
                      EffectiveRetentionCase(room: nil, serverDefault: nil, limits: .unlimited, effective: nil, isOutOfLimits: false),
                      EffectiveRetentionCase(room: 2.days, serverDefault: nil, limits: .init(lower: 7.days, upper: 365.days), effective: 7.days, isOutOfLimits: true),
                      EffectiveRetentionCase(room: 2.days, serverDefault: nil, limits: .init(lower: 7.days, upper: nil), effective: 7.days, isOutOfLimits: true),
                      EffectiveRetentionCase(room: 400.days, serverDefault: nil, limits: .init(lower: nil, upper: 365.days), effective: 365.days, isOutOfLimits: true),
                      EffectiveRetentionCase(room: 30.days, serverDefault: nil, limits: .init(lower: 7.days, upper: 365.days), effective: 30.days, isOutOfLimits: false),
                      EffectiveRetentionCase(room: 7.days, serverDefault: nil, limits: .init(lower: 7.days, upper: 365.days), effective: 7.days, isOutOfLimits: false),
                      EffectiveRetentionCase(room: 365.days, serverDefault: nil, limits: .init(lower: 7.days, upper: 365.days), effective: 365.days, isOutOfLimits: false),
                      EffectiveRetentionCase(room: nil, serverDefault: 90.days, limits: .init(lower: 7.days, upper: 30.days), effective: 30.days, isOutOfLimits: false)])
    func effectiveRetention(testCase: EffectiveRetentionCase) {
        let retention = RoomMessageRetention(policy: RoomRetentionPolicy(maxLifetime: testCase.room),
                                             configuration: RetentionServerConfiguration(isEnabled: true,
                                                                                         defaultMaxLifetime: testCase.serverDefault,
                                                                                         limits: testCase.limits))
        
        #expect(retention.effectiveMaxLifetime == testCase.effective)
        #expect(retention.isOutOfLimits == testCase.isOutOfLimits)
    }
}

// MARK: - Helpers

nonisolated struct EffectiveRetentionCase: Sendable, CustomTestStringConvertible {
    let room: TimeInterval?
    let serverDefault: TimeInterval?
    let limits: RetentionLimits
    let effective: TimeInterval?
    let isOutOfLimits: Bool
    
    var testDescription: String {
        "room \(days(room)), default \(days(serverDefault)), limits \(days(limits.lower))...\(days(limits.upper))"
    }
    
    private func days(_ value: TimeInterval?) -> String {
        value.map { "\(Int($0 / 1.days))d" } ?? "none"
    }
}

private nonisolated extension Int {
    var days: TimeInterval {
        TimeInterval(self) * 24 * 60 * 60
    }
}
