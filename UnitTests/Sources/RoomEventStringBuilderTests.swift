//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import MatrixRustSDK
import Testing

struct RoomEventStringBuilderTests {
    /// Serialises tests that mutate the process-wide localisation overrides: Swift Testing runs
    /// suites concurrently and the override is a `nonisolated(unsafe)` global.
    private static let overridesLock = NSLock()
    
    private func withOverrideLocalizations(_ languages: [String], _ body: () -> Void) {
        Self.overridesLock.lock()
        defer { Self.overridesLock.unlock() }
        
        Bundle.overrideLocalizations = languages
        body()
        Bundle.overrideLocalizations = nil
    }
    
    private let ownUserID: String
    private let stringBuilder: RoomEventStringBuilder
    
    init() {
        ownUserID = "@alice:matrix.org"
        let stateEventStringBuilder = RoomStateEventStringBuilder(userID: ownUserID)
        let attributedStringBuilder = AttributedStringBuilder(mentionBuilder: MentionBuilder())
        
        stringBuilder = RoomEventStringBuilder(stateEventStringBuilder: stateEventStringBuilder,
                                               messageEventStringBuilder: RoomMessageEventStringBuilder(attributedStringBuilder: attributedStringBuilder,
                                                                                                        style: .senderPrefixed),
                                               shouldPrefixSenderName: true)
    }
    
    @Test
    func senderPrefix() {
        // The prefix strings are localized; pin English so the test doesn't depend on the
        // simulator's locale.
        withOverrideLocalizations(["en"]) {
            let ownMessageString = stringBuilder.buildAttributedString(for: makeMessageItem(senderID: ownUserID, senderDisplayName: "Alice"))
            #expect(ownMessageString?.string == "You: Hello, World!", "Your own messages should be prefixed with 'You'")
            
            let otherMessageString = stringBuilder.buildAttributedString(for: makeMessageItem(senderID: "@bob:matrix.org", senderDisplayName: "Bob"))
            #expect(otherMessageString?.string == "Bob: Hello, World!", "Everyone else's messages should be prefixed with their display name.")
            
            let ambiguousMessageString = stringBuilder.buildAttributedString(for: makeMessageItem(senderID: "@charlie:matrix.org",
                                                                                                  senderDisplayName: "Charlie",
                                                                                                  senderDisplayNameAmbiguous: true))
            #expect(ambiguousMessageString?.string == "Charlie (@charlie:matrix.org): Hello, World!",
                    "Messages from senders with ambiguous display names should include their user ID in the prefix.")
            
            let ownEmoteString = stringBuilder.buildAttributedString(for: makeMessageItem(senderID: ownUserID,
                                                                                          senderDisplayName: "Alice",
                                                                                          type: .emote,
                                                                                          message: "laughs"))
            #expect(ownEmoteString?.string == "* Alice laughs", "Your own emotes shouldn't contain 'You'")
            
            let otherEmoteString = stringBuilder.buildAttributedString(for: makeMessageItem(senderID: "@bob:matrix.org",
                                                                                            senderDisplayName: "Bob",
                                                                                            type: .emote,
                                                                                            message: "sighs"))
            #expect(otherEmoteString?.string == "* Bob sighs", "Everyone else's emotes should contain their display name.")
            
            let ownPollString = stringBuilder.buildAttributedString(for: makePollItem(senderID: ownUserID, senderDisplayName: "Alice"))
            #expect(ownPollString?.string == "You: Poll: Which is better?", "Your own polls should be prefixed with 'You'")
            
            let otherPollString = stringBuilder.buildAttributedString(for: makePollItem(senderID: "@bob:matrix.org", senderDisplayName: "Bob"))
            #expect(otherPollString?.string == "Bob: Poll: Which is better?", "Everyone else's polls should be prefixed with their display name.")
        }
    }
    
    // MARK: - Friend request markers (ADR 0016)
    
    /// Wire v2 markers (`m.text` with the custom format) render the localized label as plain
    /// text — never the formatted body as HTML. Pinned to English: the label is localized and
    /// the simulator locale may differ.
    @Test
    func wireV2MarkerRendersLocalizedLabel() {
        withOverrideLocalizations(["en"]) {
            let marker = makeMessageItem(senderID: "@bob:matrix.org",
                                         senderDisplayName: "Bob",
                                         content: .text(content: .init(body: "👋 Friend request",
                                                                       formatted: .init(format: .unknown(format: "io.nagi.friend_request"),
                                                                                        body: "👋 Friend request"))))
            let rendered = stringBuilder.buildAttributedString(for: marker)?.string
            #expect(rendered == "Bob: 👋 Friend request", "Wire v2 markers should render the plain localized label")
        }
    }
    
    /// Legacy `m.friend_request` msgtype markers keep rendering the localized label.
    @Test
    func legacyMarkerRendersLocalizedLabel() {
        withOverrideLocalizations(["en"]) {
            let marker = makeMessageItem(senderID: "@bob:matrix.org",
                                         senderDisplayName: "Bob",
                                         content: .other(msgtype: "m.friend_request", body: "👋 Friend request"))
            let rendered = stringBuilder.buildAttributedString(for: marker)?.string
            #expect(rendered == "Bob: 👋 Friend request", "Legacy markers should render the plain localized label")
        }
    }
    
    // MARK: - Helpers
    
    private enum MockMessageType { case textMessage, emote }
    
    private func makeMessageItem(senderID: String,
                                 senderDisplayName: String? = nil,
                                 senderDisplayNameAmbiguous: Bool = false,
                                 type: MockMessageType = .textMessage,
                                 message: String = "Hello, World!",
                                 content: MessageType? = nil) -> EventTimelineItemProxy {
        let resolvedContent: MessageType
        if let content {
            // Pre-set content (friend-request marker cases).
            resolvedContent = content
        } else {
            switch type {
            case .textMessage: resolvedContent = makeTextContent(message: message)
            case .emote: resolvedContent = makeEmoteContent(message: message)
            }
        }
        
        return .init(item: .init(configuration: .init(eventID: "1234",
                                                      sender: senderID,
                                                      senderProfile: .ready(displayName: senderDisplayName,
                                                                            displayNameAmbiguous: senderDisplayNameAmbiguous,
                                                                            avatarUrl: nil,
                                                                            status: nil,
                                                                            call: nil),
                                                      isOwn: senderID == ownUserID,
                                                      content: .msgLike(content: .init(kind: .message(content: .init(msgType: resolvedContent,
                                                                                                                     body: message,
                                                                                                                     isEdited: false,
                                                                                                                     mentions: nil)),
                                                                                       inReplyTo: nil,
                                                                                       threadRoot: nil,
                                                                                       threadSummary: nil)))),
                     uniqueID: .init("0"))
    }
    
    private func makeTextContent(message: String) -> MessageType {
        .text(content: .init(body: message, formatted: nil))
    }
    
    private func makeEmoteContent(message: String) -> MessageType {
        .emote(content: .init(body: message, formatted: nil))
    }
    
    private func makePollItem(senderID: String,
                              senderDisplayName: String? = nil,
                              senderDisplayNameAmbiguous: Bool = false,
                              question: String = "Which is better?") -> EventTimelineItemProxy {
        .init(item: .init(configuration: .init(eventID: "1234",
                                               sender: senderID,
                                               senderProfile: .ready(displayName: senderDisplayName,
                                                                     displayNameAmbiguous: senderDisplayNameAmbiguous,
                                                                     avatarUrl: nil,
                                                                     status: nil,
                                                                     call: nil),
                                               isOwn: senderID == ownUserID,
                                               content: .msgLike(content: .init(kind: .poll(question: question,
                                                                                            kind: .disclosed,
                                                                                            maxSelections: 1,
                                                                                            answers: [],
                                                                                            votes: [:],
                                                                                            endTime: nil,
                                                                                            hasBeenEdited: false),
                                                                                inReplyTo: nil,
                                                                                threadRoot: nil,
                                                                                threadSummary: nil)))),
              uniqueID: .init("0"))
    }
}
