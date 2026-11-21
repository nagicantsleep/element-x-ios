//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Testing

@MainActor
struct FriendsServiceTests {
    // MARK: - Marker observation (pure logic)
    
    @Test
    func processObservedMarkerRecordsIncomingRequest() {
        var requests = [String: FriendRequest]()
        
        let recorded = FriendsService.processObservedMarker(sender: "@bob:example.org",
                                                            ownUserID: "@alice:example.org",
                                                            localRequests: &requests,
                                                            timestamp: 123)
        
        #expect(recorded)
        #expect(requests["@bob:example.org"]?.direction == .incoming)
        #expect(requests["@bob:example.org"]?.userID == "@bob:example.org")
        #expect(requests["@bob:example.org"]?.createdAt == 123)
    }
    
    @Test
    func processObservedMarkerIsIdempotent() {
        var requests = [String: FriendRequest]()
        _ = FriendsService.processObservedMarker(sender: "@bob:example.org",
                                                 ownUserID: "@alice:example.org",
                                                 localRequests: &requests,
                                                 timestamp: 123)
        
        let recorded = FriendsService.processObservedMarker(sender: "@bob:example.org",
                                                            ownUserID: "@alice:example.org",
                                                            localRequests: &requests,
                                                            timestamp: 456)
        
        #expect(!recorded)
        #expect(requests.count == 1)
        #expect(requests["@bob:example.org"]?.createdAt == 123, "The original request must be kept.")
    }
    
    @Test
    func processObservedMarkerSkipsOwnSender() {
        var requests = [String: FriendRequest]()
        
        let recorded = FriendsService.processObservedMarker(sender: "@alice:example.org",
                                                            ownUserID: "@alice:example.org",
                                                            localRequests: &requests,
                                                            timestamp: 123)
        
        #expect(!recorded)
        #expect(requests.isEmpty)
    }
    
    @Test
    func processObservedMarkerSkipsEmptySender() {
        var requests = [String: FriendRequest]()
        
        let recorded = FriendsService.processObservedMarker(sender: "",
                                                            ownUserID: "@alice:example.org",
                                                            localRequests: &requests,
                                                            timestamp: 123)
        
        #expect(!recorded)
        #expect(requests.isEmpty)
    }
    
    @Test
    func processObservedMarkerKeepsExistingRequests() {
        var requests = ["@carol:example.org": FriendRequest(userID: "@carol:example.org",
                                                            displayName: "Carol",
                                                            direction: .outgoing,
                                                            createdAt: 1)]
        
        let recorded = FriendsService.processObservedMarker(sender: "@bob:example.org",
                                                            ownUserID: "@alice:example.org",
                                                            localRequests: &requests,
                                                            timestamp: 123)
        
        #expect(recorded)
        #expect(requests.count == 2)
        #expect(requests["@carol:example.org"]?.displayName == "Carol")
    }
    
    // MARK: - Account data shapes
    
    @Test
    func friendEntryDecoding() {
        let entry = FriendsService.decodeFriendEntry(["user_id": "@bob:example.org",
                                                      "added_at": 100],
                                                     userID: "@bob:example.org")
        
        #expect(entry?.userID == "@bob:example.org")
        #expect(entry?.addedAt == 100)
        #expect(entry?.displayName == nil)
    }
    
    @Test
    func friendRequestRoundtrip() {
        let original = FriendRequest(userID: "@bob:example.org",
                                     displayName: "Bob",
                                     direction: .outgoing,
                                     createdAt: 42)
        
        let decoded = FriendsService.decodeFriendRequest(FriendsService.encodeFriendRequest(original),
                                                         userID: "@bob:example.org")
        
        #expect(decoded == original)
    }
    
    @Test
    func friendRequestDecodingRejectsUnknownDirection() {
        let decoded = FriendsService.decodeFriendRequest(["user_id": "@bob:example.org",
                                                          "direction": "sideways",
                                                          "created_at": 42],
                                                         userID: "@bob:example.org")
        
        #expect(decoded == nil)
    }
    
    // MARK: - URL construction
    
    @Test
    func matrixToURLPercentEncodesUserID() {
        let url = FriendsService.matrixToURL(for: "@bob:example.org")
        
        #expect(url?.absoluteString == "https://matrix.to/#/%40bob%3Aexample.org")
    }
    
    @Test
    func matrixToURLRejectsInvalidUserID() {
        #expect(FriendsService.matrixToURL(for: "bob") == nil)
        #expect(FriendsService.matrixToURL(for: "@bob") == nil)
    }
    
    @Test
    func isValidUserID() {
        #expect(FriendsService.isValidUserID("@bob:example.org"))
        #expect(!FriendsService.isValidUserID("bob:example.org"))
        #expect(!FriendsService.isValidUserID("@bob"))
    }
    
    // MARK: - Union merge
    
    /// The union-by-user_id merge of the server edge list with the local mirror, using the same
    /// shapes the REST endpoint and account data produce.
    @Test
    func localOnlyEntriesAreKeptWhenMerging() {
        let serverFriends = FriendsService.decodeFriends(from: ["friends": [["user_id": "@bob:example.org",
                                                                             "added_at": 100]]])
        let localFriends = ["@carol:example.org": FriendEntry(userID: "@carol:example.org",
                                                              displayName: "Carol",
                                                              addedAt: 50)]
        
        var merged = serverFriends.map { FriendEntry(userID: $0.0,
                                                     displayName: localFriends[$0.0]?.displayName,
                                                     addedAt: $0.1.addedAt) }
        for (userID, entry) in localFriends where !merged.contains(where: { $0.userID == userID }) {
            merged.append(entry)
        }
        
        #expect(merged.count == 2)
        #expect(merged.contains { $0.userID == "@bob:example.org" && $0.addedAt == 100 })
        #expect(merged.contains { $0.userID == "@carol:example.org" && $0.displayName == "Carol" })
    }
    
    /// The loadState dedupe predicate: only requests missing server side are treated as
    /// local-only (web-originated).
    @Test
    func localOnlyRequestDetection() {
        let serverUserIDs = Set(["@bob:example.org"])
        let localRequests = ["@bob:example.org": FriendRequest(userID: "@bob:example.org",
                                                               displayName: nil,
                                                               direction: .incoming,
                                                               createdAt: 1),
                             "@carol:example.org": FriendRequest(userID: "@carol:example.org",
                                                                 displayName: nil,
                                                                 direction: .outgoing,
                                                                 createdAt: 2)]
        
        let localOnly = localRequests.filter { !serverUserIDs.contains($0.key) }.map(\.value)
        
        #expect(localOnly.count == 1)
        #expect(localOnly.first?.direction == .outgoing)
    }
}
