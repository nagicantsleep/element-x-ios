//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

// MARK: - Model

/// An accepted friend, mirrored between the server graph and the `m.friend_list` account data.
struct FriendEntry: Equatable, Hashable, Sendable {
    let userID: String
    let displayName: String?
    let addedAt: Double
}

/// A pending friend request in either direction.
enum FriendRequestDirection: String, Sendable {
    case incoming = "in"
    case outgoing = "out"
}

struct FriendRequest: Equatable, Hashable, Sendable {
    let userID: String
    let displayName: String?
    let direction: FriendRequestDirection
    let createdAt: Double
}

/// The outcome of `POST /_synapse/client/friends/request`.
enum FriendRequestOutcome: String, Sendable {
    case requested
    case alreadyFriends = "already_friends"
    case accepted
}

enum FriendsError: Error, Equatable {
    case invalidUserID
    case unauthorized
    case limitReached
    case requestNotFound
    case network
}

// MARK: - Service

// sourcery: AutoMockable
protocol FriendsServiceProtocol {
    /// The union of the server friend graph and the local `m.friend_list` mirror.
    func friends() async -> Result<[FriendEntry], FriendsError>
    /// Pending requests from the server merged with the locally recorded web-originated ones.
    func requests() async -> Result<(incoming: [FriendRequest], outgoing: [FriendRequest]), FriendsError>
    /// Adds a friend request on the server and mirrors it as a DM marker for web clients.
    func sendRequest(userID: String, displayName: String?) async -> Result<FriendRequestOutcome, FriendsError>
    /// Accepts a pending request, falling back to a local-only edge for web-originated requests.
    func accept(userID: String) async -> Result<Void, FriendsError>
    /// Cancels an outgoing request or removes an existing friend, both locally and server side.
    func remove(userID: String) async -> Result<Void, FriendsError>
    /// Scans the DM rooms' latest messages for friend-request markers (web-originated requests,
    /// detected by `MessageType.isFriendRequestMarker`) and records them as incoming requests.
    func observeIncomingRequests() async
}

final class FriendsService: FriendsServiceProtocol {
    private let clientProxy: ClientProxyProtocol
    
    init(clientProxy: ClientProxyProtocol) {
        self.clientProxy = clientProxy
    }
    
    // MARK: API surface
    
    func friends() async -> Result<[FriendEntry], FriendsError> {
        switch await loadState() {
        case .success(let state):
            return .success(state.friends.sorted { $0.addedAt < $1.addedAt })
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func requests() async -> Result<(incoming: [FriendRequest], outgoing: [FriendRequest]), FriendsError> {
        switch await loadState() {
        case .success(let state):
            return .success((state.incoming.sorted { $0.createdAt < $1.createdAt },
                             state.outgoing.sorted { $0.createdAt < $1.createdAt }))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func sendRequest(userID: String, displayName: String?) async -> Result<FriendRequestOutcome, FriendsError> {
        guard Self.isValidUserID(userID) else { return .failure(.invalidUserID) }
        
        switch await request(method: "POST", path: Self.requestPath, body: ["user_id": userID]) {
        case .success(let response):
            guard let outcome = response["result"] as? String,
                  let result = FriendRequestOutcome(rawValue: outcome) else {
                return .failure(.network)
            }
            
            if result == .accepted {
                // The target had already asked us, the server completed the edge.
                await writeLocalFriend(userID: userID, displayName: displayName)
            } else if result == .requested {
                await recordRequest(FriendRequest(userID: userID,
                                                  displayName: displayName,
                                                  direction: .outgoing,
                                                  createdAt: Date().timeIntervalSince1970 * 1000))
                // Notify web clients, which only see requests through the DM marker.
                if case .failure = await sendDMMarker(userID: userID) {
                    return .failure(.network)
                }
            }
            
            return .success(result)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func accept(userID: String) async -> Result<Void, FriendsError> {
        switch await request(method: "POST", path: Self.acceptPath, body: ["user_id": userID]) {
        case .success:
            return await removeAllRequestEntriesLocally(userID: userID)
        case .failure(.requestNotFound):
            // Web-originated requests never reach the server graph; mirror web's addFriend instead.
            await writeLocalFriend(userID: userID, displayName: nil)
            return await removeAllRequestEntriesLocally(userID: userID)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func remove(userID: String) async -> Result<Void, FriendsError> {
        // A 404 is expected when the request only ever existed locally (web-originated); the
        // merged list resyncs the server state on next load, so always clear locally.
        switch await request(method: "POST", path: Self.removePath, body: ["user_id": userID]) {
        case .failure(.unauthorized):
            return .failure(.unauthorized)
        default:
            break
        }
        
        return await removeAllLocally(userID: userID)
    }
    
    func observeIncomingRequests() async {
        for summary in clientProxy.staticRoomSummaryProvider.roomListPublisher.value where summary.isDirect {
            guard case let .joined(roomProxy) = await clientProxy.roomForIdentifier(summary.id),
                  let (sender, marker) = await roomProxy.latestMessageMarker(),
                  marker.isFriendRequestMarker,
                  sender != clientProxy.userID else {
                continue
            }
            
            guard case .success(var localState) = await readLocalState() else { continue }
            
            if Self.processObservedMarker(sender: sender,
                                          ownUserID: clientProxy.userID,
                                          localRequests: &localState.requests,
                                          timestamp: Date().timeIntervalSince1970 * 1000) {
                await mutateLocalRequests { $0 = localState.requests }
            }
        }
    }
    
    // MARK: State loading
    
    private struct FriendsState {
        var friends = [FriendEntry]()
        var incoming = [FriendRequest]()
        var outgoing = [FriendRequest]()
    }
    
    /// Merges the server graph with the client-authoritative account data (union by `user_id`).
    private func loadState() async -> Result<FriendsState, FriendsError> {
        guard case let .success(serverFriends) = await request(method: "GET", path: Self.listPath, body: nil) else {
            return .failure(.network)
        }
        guard case let .success(serverRequests) = await request(method: "GET", path: Self.requestsPath, body: nil) else {
            return .failure(.network)
        }
        guard case let .success(localState) = await readLocalState() else {
            return .failure(.network)
        }
        
        var state = FriendsState()
        
        for (userID, entry) in Self.decodeFriends(from: serverFriends) {
            state.friends.append(FriendEntry(userID: userID,
                                             displayName: entry.displayName ?? localState.friends[userID]?.displayName,
                                             addedAt: entry.addedAt))
        }
        // Local-only entries are edges accepted on web while the server plugin was absent.
        for (userID, entry) in localState.friends where !state.friends.contains(where: { $0.userID == userID }) {
            state.friends.append(entry)
        }
        
        for (userID, createdAt) in Self.decodeRequests(from: serverRequests, field: "incoming") {
            state.incoming.append(FriendRequest(userID: userID,
                                                displayName: localState.requests[userID]?.displayName,
                                                direction: .incoming,
                                                createdAt: createdAt))
        }
        for (userID, createdAt) in Self.decodeRequests(from: serverRequests, field: "outgoing") {
            state.outgoing.append(FriendRequest(userID: userID,
                                                displayName: localState.requests[userID]?.displayName,
                                                direction: .outgoing,
                                                createdAt: createdAt))
        }
        // Web-originated requests exist only in the local account data.
        let serverRequestUserIDs = Set(state.incoming.map(\.userID) + state.outgoing.map(\.userID))
        for (userID, request) in localState.requests where !serverRequestUserIDs.contains(userID) {
            switch request.direction {
            case .incoming: state.incoming.append(request)
            case .outgoing: state.outgoing.append(request)
            }
        }
        
        return .success(state)
    }
    
    // MARK: Local account data (m.friend_list / m.friend_requests)
    
    struct LocalState {
        var friends = [String: FriendEntry]()
        var requests = [String: FriendRequest]()
    }
    
    private func readLocalState() async -> Result<LocalState, FriendsError> {
        var state = LocalState()
        
        switch await clientProxy.accountData(eventType: Self.friendListEventType) {
        case .success(let json):
            state.friends = Self.decodeMap(json) { FriendsService.decodeFriendEntry($1, userID: $0) }
        case .failure:
            return .failure(.network)
        }
        
        switch await clientProxy.accountData(eventType: Self.friendRequestsEventType) {
        case .success(let json):
            state.requests = Self.decodeMap(json) { FriendsService.decodeFriendRequest($1, userID: $0) }
        case .failure:
            return .failure(.network)
        }
        
        return .success(state)
    }
    
    private func recordRequest(_ request: FriendRequest) async -> Result<Void, FriendsError> {
        await mutateLocalRequests { $0[request.userID] = request }
    }
    
    private func writeLocalFriend(userID: String, displayName: String?) async {
        await mutateLocalFriends {
            let addedAt = $0[userID]?.addedAt ?? Date().timeIntervalSince1970 * 1000
            $0[userID] = FriendEntry(userID: userID,
                                     displayName: displayName ?? $0[userID]?.displayName,
                                     addedAt: addedAt)
        }
        await mutateLocalRequests { $0.removeValue(forKey: userID) }
    }
    
    private func removeAllRequestEntriesLocally(userID: String) async -> Result<Void, FriendsError> {
        await mutateLocalRequests { $0.removeValue(forKey: userID) }
    }
    
    private func removeAllLocally(userID: String) async -> Result<Void, FriendsError> {
        let friends = await mutateLocalFriends { $0.removeValue(forKey: userID) }
        let requests = await mutateLocalRequests { $0.removeValue(forKey: userID) }
        if case .success = friends, case .success = requests {
            return .success(())
        }
        return .failure(.network)
    }
    
    private func mutateLocalFriends(_ mutation: (inout [String: FriendEntry]) -> Void) async -> Result<Void, FriendsError> {
        await mutateLocalAccountData(eventType: Self.friendListEventType,
                                     decode: { FriendsService.decodeFriendEntry($1, userID: $0) },
                                     encode: { FriendsService.encodeFriendEntry($0) },
                                     mutation)
    }
    
    private func mutateLocalRequests(_ mutation: (inout [String: FriendRequest]) -> Void) async -> Result<Void, FriendsError> {
        await mutateLocalAccountData(eventType: Self.friendRequestsEventType,
                                     decode: { FriendsService.decodeFriendRequest($1, userID: $0) },
                                     encode: { FriendsService.encodeFriendRequest($0) },
                                     mutation)
    }
    
    /// Read-modify-write cycle over one account data map.
    private func mutateLocalAccountData<Value>(eventType: String,
                                               decode: (String, Any) -> Value?,
                                               encode: (Value) -> Any,
                                               _ mutation: (inout [String: Value]) -> Void) async -> Result<Void, FriendsError> {
        var content = [String: Value]()
        if case .success(let json) = await clientProxy.accountData(eventType: eventType) {
            content = Self.decodeMap(json, decode)
        }
        
        mutation(&content)
        
        let encoded = content.mapValues(encode)
        guard let payload = try? JSONSerialization.data(withJSONObject: encoded),
              let json = String(data: payload, encoding: .utf8) else {
            return .failure(.network)
        }
        return await clientProxy.setAccountData(eventType: eventType, content: json).mapError { _ in .network }
    }
    
    // MARK: REST
    
    private func request(method: String, path: String, body: [String: String]?) async -> Result<[String: Any], FriendsError> {
        guard let token = await clientProxy.accessToken() else { return .failure(.unauthorized) }
        let joined = clientProxy.homeserver.hasSuffix("/") && path.hasPrefix("/")
            ? String(clientProxy.homeserver.dropLast()) + path
            : clientProxy.homeserver + path
        guard let url = URL(string: joined) else { return .failure(.network) }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        do {
            let (data, response) = try await URLSession.shared.dataWithRetry(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else { return .failure(.network) }
            
            switch httpResponse.statusCode {
            case 200...299:
                guard !data.isEmpty else { return .success([:]) }
                let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                return .success(object ?? [:])
            case 401, 403:
                return .failure(.unauthorized)
            case 404:
                return .failure(.requestNotFound)
            case 413:
                return .failure(.limitReached)
            default:
                return .failure(.network)
            }
        } catch {
            MXLog.error("Friends request \(method) \(path) failed: \(error)")
            return .failure(.network)
        }
    }
    
    // MARK: DM marker (web interop)
    
    /// Sends the friend-request DM marker so web clients can observe the request. Wire v2 (ADR
    /// 0016): an `m.text` carrying the custom `io.nagi.friend_request` formatted-body format —
    /// the SDK's default event filter drops unknown msgtypes, so a `m.friend_request` marker
    /// would never reach Element X's timeline. Web detects both shapes.
    private func sendDMMarker(userID: String) async -> Result<Void, FriendsError> {
        let roomID: String?
        switch clientProxy.directRoomForUserID(userID) {
        case .success(let existing):
            roomID = existing
        case .failure:
            roomID = nil
        }
        
        let targetRoomID: String
        if let roomID {
            targetRoomID = roomID
        } else {
            switch await clientProxy.createDirectRoom(with: userID, expectedRoomName: nil) {
            case .success(let created):
                targetRoomID = created
            case .failure:
                return .failure(.network)
            }
        }
        
        guard case let .joined(roomProxy) = await clientProxy.roomForIdentifier(targetRoomID) else {
            return .failure(.network)
        }
        
        // Built through the FFI message content builder: `messageEventContentNew` maps the SDK
        // `MessageType` (here `m.text` with the custom marker format) to the wire content.
        let content: RoomMessageEventContentWithoutRelation
        do {
            content = try messageEventContentNew(msgtype: .text(content: .init(body: Self.markerBody,
                                                                               formatted: .init(format: .unknown(format: Self.markerFormat),
                                                                                                body: Self.markerBody))))
        } catch {
            MXLog.error("Failed building the friend-request marker content: \(error)")
            return .failure(.network)
        }
        return await roomProxy.timeline.sendMessageEventContent(content).mapError { _ in .network }
    }
    
    // MARK: Constants & helpers
    
    static let friendListEventType = "m.friend_list"
    static let friendRequestsEventType = "m.friend_requests"
    /// Wire v2 marker shape (ADR 0016): `m.text` with this custom format in the formatted body.
    /// Legacy `m.friend_request` msgtype markers from web are still detected on read.
    nonisolated static let markerFormat = friendRequestMarkerFormat
    nonisolated static let markerBody = "👋 Friend request"
    
    private static let listPath = "/_synapse/client/friends"
    private static let requestsPath = "/_synapse/client/friends/requests"
    private static let requestPath = "/_synapse/client/friends/request"
    private static let acceptPath = "/_synapse/client/friends/accept"
    private static let removePath = "/_synapse/client/friends/remove"
    
    nonisolated static func isValidUserID(_ userID: String) -> Bool {
        userID.hasPrefix("@") && userID.contains(":")
    }
    
    /// The matrix.to link encoded into the personal QR code.
    nonisolated static func matrixToURL(for userID: String) -> URL? {
        guard isValidUserID(userID) else { return nil }
        // Percent-encode like web's encodeURIComponent, keeping the unreserved marks readable.
        var allowed = CharacterSet.alphanumerics
        allowed.formUnion(CharacterSet(charactersIn: "-_.~!*'()"))
        let encoded = userID.addingPercentEncoding(withAllowedCharacters: allowed) ?? userID
        return URL(string: "https://matrix.to/#/\(encoded)")
    }
    
    /// Marks an `m.friend_request` marker observed in a timeline as an incoming request. Idempotent.
    nonisolated static func processObservedMarker(sender: String,
                                                  ownUserID: String,
                                                  localRequests: inout [String: FriendRequest],
                                                  timestamp: Double) -> Bool {
        guard !sender.isEmpty, sender != ownUserID, localRequests[sender] == nil else { return false }
        localRequests[sender] = FriendRequest(userID: sender,
                                              displayName: nil,
                                              direction: .incoming,
                                              createdAt: timestamp)
        return true
    }
    
    nonisolated static func decodeFriends(from response: [String: Any]) -> [(String, FriendEntry)] {
        (response["friends"] as? [[String: Any]] ?? []).compactMap { entry in
            guard let userID = entry["user_id"] as? String, !userID.isEmpty else { return nil }
            return (userID, FriendEntry(userID: userID,
                                        displayName: entry["display_name"] as? String,
                                        addedAt: timestamp(from: entry["added_at"])))
        }
    }
    
    nonisolated static func decodeRequests(from response: [String: Any], field: String) -> [(String, Double)] {
        (response[field] as? [[String: Any]] ?? []).compactMap { entry in
            guard let userID = entry["user_id"] as? String, !userID.isEmpty else { return nil }
            return (userID, timestamp(from: entry["created_at"]))
        }
    }
    
    nonisolated static func timestamp(from value: Any?) -> Double {
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        return 0
    }
    
    nonisolated static func decodeFriendEntry(_ value: Any, userID: String) -> FriendEntry? {
        guard let object = value as? [String: Any] else { return nil }
        return FriendEntry(userID: (object["user_id"] as? String) ?? userID,
                           displayName: object["display_name"] as? String,
                           addedAt: timestamp(from: object["added_at"]))
    }
    
    nonisolated static func encodeFriendEntry(_ entry: FriendEntry) -> Any {
        var object: [String: Any] = ["user_id": entry.userID, "added_at": entry.addedAt]
        if let displayName = entry.displayName {
            object["display_name"] = displayName
        }
        return object
    }
    
    nonisolated static func decodeFriendRequest(_ value: Any, userID: String) -> FriendRequest? {
        guard let object = value as? [String: Any],
              let directionRaw = object["direction"] as? String,
              let direction = FriendRequestDirection(rawValue: directionRaw) else { return nil }
        return FriendRequest(userID: (object["user_id"] as? String) ?? userID,
                             displayName: object["display_name"] as? String,
                             direction: direction,
                             createdAt: timestamp(from: object["created_at"]))
    }
    
    nonisolated static func encodeFriendRequest(_ request: FriendRequest) -> Any {
        var object: [String: Any] = ["user_id": request.userID,
                                     "direction": request.direction.rawValue,
                                     "created_at": request.createdAt]
        if let displayName = request.displayName {
            object["display_name"] = displayName
        }
        return object
    }
    
    nonisolated static func decodeMap<Value>(_ json: String?, _ decode: (String, Any) -> Value?) -> [String: Value] {
        guard let data = json?.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        var map = [String: Value]()
        for (userID, value) in object {
            if let decoded = decode(userID, value) {
                map[userID] = decoded
            }
        }
        return map
    }
}
