//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// A message scheduled for delayed delivery with MSC4140, recorded per device so
/// the "Scheduled" panel can list and manage it (web mirrors this shape in its
/// `mx_prod_scheduled_messages` store).
struct ScheduledMessageRecord: Codable, Equatable, Identifiable, Sendable {
    let delayId: String
    let roomId: String
    /// Epoch milliseconds at which the server will deliver the message.
    let sendAt: Double
    let content: [String: String]
    let eventType: String
    /// Reserved for wave 3 (self-destructing messages); never set by wave 2.
    let selfDestructAfterMs: Double?
    
    var id: String {
        delayId
    }
    
    var messageBody: String {
        content["body"] ?? ""
    }
    
    init(delayId: String,
         roomId: String,
         sendAt: Double,
         content: [String: String],
         eventType: String,
         selfDestructAfterMs: Double? = nil) {
        self.delayId = delayId
        self.roomId = roomId
        self.sendAt = sendAt
        self.content = content
        self.eventType = eventType
        self.selfDestructAfterMs = selfDestructAfterMs
    }
}

/// Per-device store of scheduled messages, persisted in user defaults so the
/// records survive app restarts.
final class ScheduledMessageStore {
    private let defaults: UserDefaults
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    /// All the records for a room (or every room when `roomID` is `nil`), ordered by delivery time.
    func records(roomID: String? = nil) -> [ScheduledMessageRecord] {
        load().filter { roomID == nil || $0.roomId == roomID }
            .sorted { $0.sendAt < $1.sendAt }
    }
    
    /// Inserts the record, replacing any existing one with the same `delayId`.
    func save(_ record: ScheduledMessageRecord) {
        var records = load().filter { $0.delayId != record.delayId }
        records.append(record)
        persist(records)
    }
    
    func remove(delayId: String) {
        persist(load().filter { $0.delayId != delayId })
    }
    
    // MARK: - Private
    
    private func load() -> [ScheduledMessageRecord] {
        guard let data = defaults.data(forKey: Self.storageKey) else { return [] }
        return (try? JSONDecoder().decode([ScheduledMessageRecord].self, from: data)) ?? []
    }
    
    private func persist(_ records: [ScheduledMessageRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
    
    private static let storageKey = "scheduledMessages"
}
