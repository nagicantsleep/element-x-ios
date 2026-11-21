//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// A delayed event the homeserver currently holds for the user (MSC4140 listing).
struct DelayedEventInfo: Equatable, Sendable {
    let delayId: String
    let roomId: String
    let eventType: String
    let delayMs: Double
}

enum SchedulingError: Error, Equatable {
    /// The homeserver doesn't have the MSC4140 unstable feature enabled (404 / M_UNRECOGNIZED).
    case unsupported
    case failure
}

// MARK: - Service

// sourcery: AutoMockable
protocol SchedulingServiceProtocol {
    /// Whether the homeserver advertises `org.matrix.msc4140` in `GET /versions`.
    /// The check is performed once per session (per homeserver) and cached.
    func isSupported() async -> Bool
    /// Schedules a message for delivery at `sendAt` through MSC4140 and records it locally.
    func schedule(roomID: String, eventType: String, content: [String: String], sendAt: Date) async -> Result<ScheduledMessageRecord, SchedulingError>
    /// Delivers a scheduled message immediately and drops its local record.
    func sendNow(delayId: String) async -> Result<Void, SchedulingError>
    /// Cancels a scheduled message without delivering it and drops its local record.
    func cancel(delayId: String) async -> Result<Void, SchedulingError>
    /// Lists the delayed events the server currently holds for the user.
    func delayedEvents() async -> Result<[DelayedEventInfo], SchedulingError>
    /// The locally recorded scheduled messages for a room, ordered by delivery time.
    func records(roomID: String) -> [ScheduledMessageRecord]
}

/// REST client for the MSC4140 delayed events endpoints, authenticated with the
/// session's homeserver URL and access token (no Rust SDK support exists).
final class SchedulingService: SchedulingServiceProtocol {
    private let clientProxy: ClientProxyProtocol
    private let recordStore: ScheduledMessageStore
    private let urlSession: URLSession
    
    /// `GET /versions` is queried once per session (per homeserver), like web's
    /// `isSchedulingSupported`.
    private static var supportCache = [String: Bool]()
    
    init(clientProxy: ClientProxyProtocol,
         urlSession: URLSession = .shared,
         recordStore: ScheduledMessageStore = ScheduledMessageStore()) {
        self.clientProxy = clientProxy
        self.urlSession = urlSession
        self.recordStore = recordStore
    }
    
    // MARK: API surface
    
    func isSupported() async -> Bool {
        if let supported = Self.supportCache[clientProxy.homeserver] {
            return supported
        }
        
        guard case let .success(response) = await request(method: "GET", path: Self.versionsPath) else {
            // Network failure: leave the cache empty so the next check retries.
            return false
        }
        
        let supported = ((response["unstable_features"] as? [String: Any])?[Self.unstableFeature] as? Bool) == true
        Self.supportCache[clientProxy.homeserver] = supported
        return supported
    }
    
    func schedule(roomID: String, eventType: String, content: [String: String], sendAt: Date) async -> Result<ScheduledMessageRecord, SchedulingError> {
        let delayMs = Int(max(1, (sendAt.timeIntervalSince1970 - Date().timeIntervalSince1970) * 1000))
        let transactionID = "sched-\(UUID().uuidString)"
        
        switch await request(method: "PUT",
                             path: "/rooms/\(roomID)/send/\(eventType)/\(transactionID)",
                             query: [URLQueryItem(name: Self.delayQueryParam, value: String(delayMs))],
                             body: content) {
        case .success(let response):
            guard let delayId = response["delay_id"] as? String, !delayId.isEmpty else {
                MXLog.error("Scheduling a message in \(roomID) succeeded without a delay_id")
                return .failure(.failure)
            }
            
            let record = ScheduledMessageRecord(delayId: delayId,
                                                roomId: roomID,
                                                sendAt: sendAt.timeIntervalSince1970 * 1000,
                                                content: content,
                                                eventType: eventType)
            recordStore.save(record)
            return .success(record)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func sendNow(delayId: String) async -> Result<Void, SchedulingError> {
        await update(delayId: delayId, action: .send)
    }
    
    func cancel(delayId: String) async -> Result<Void, SchedulingError> {
        await update(delayId: delayId, action: .cancel)
    }
    
    func delayedEvents() async -> Result<[DelayedEventInfo], SchedulingError> {
        switch await request(method: "GET", path: Self.delayedEventsPath) {
        case .success(let response):
            let events = (response["delayed_events"] as? [[String: Any]] ?? []).compactMap { entry -> DelayedEventInfo? in
                guard let delayId = entry["delay_id"] as? String, !delayId.isEmpty else { return nil }
                return DelayedEventInfo(delayId: delayId,
                                        roomId: entry["room_id"] as? String ?? "",
                                        eventType: entry["type"] as? String ?? "",
                                        delayMs: SchedulingService.timestamp(from: entry["delay_ms"]))
            }
            return .success(events)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func records(roomID: String) -> [ScheduledMessageRecord] {
        recordStore.records(roomID: roomID)
    }
    
    // MARK: - Private
    
    private enum UpdateAction: String {
        case send
        case cancel
        case restart
    }
    
    private func update(delayId: String, action: UpdateAction) async -> Result<Void, SchedulingError> {
        switch await request(method: "POST",
                             path: "\(Self.delayedEventsPath)/\(delayId)",
                             body: ["action": action.rawValue]) {
        case .success:
            recordStore.remove(delayId: delayId)
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: REST
    
    private func request(method: String,
                         path: String,
                         query: [URLQueryItem]? = nil,
                         body: [String: String]? = nil) async -> Result<[String: Any], SchedulingError> {
        guard let token = await clientProxy.accessToken() else { return .failure(.failure) }
        
        var components = URLComponents(string: clientProxy.homeserver + path)
        components?.queryItems = query
        
        guard let url = components?.url else { return .failure(.failure) }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        do {
            let (data, response) = try await urlSession.dataWithRetry(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else { return .failure(.failure) }
            
            switch httpResponse.statusCode {
            case 200...299:
                guard !data.isEmpty else { return .success([:]) }
                let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                return .success(object ?? [:])
            case 404:
                return .failure(.unsupported)
            default:
                // Some servers answer 400 with M_UNRECOGNIZED instead of a 404 when the
                // unstable endpoint is unknown (feature disabled).
                if let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                   object["errcode"] as? String == Self.unrecognizedErrcode {
                    return .failure(.unsupported)
                }
                MXLog.error("Scheduling request \(method) \(path) failed with status \(httpResponse.statusCode)")
                return .failure(.failure)
            }
        } catch {
            MXLog.error("Scheduling request \(method) \(path) failed: \(error)")
            return .failure(.failure)
        }
    }
    
    // MARK: Constants & helpers
    
    static let unstableFeature = "org.matrix.msc4140"
    static let delayQueryParam = "org.matrix.msc4140.delay"
    
    private static let versionsPath = "/_matrix/client/versions"
    private static let delayedEventsPath = "/unstable/org.matrix.msc4140/delayed_events"
    private static let unrecognizedErrcode = "M_UNRECOGNIZED"
    
    nonisolated static func timestamp(from value: Any?) -> Double {
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        return 0
    }
}
