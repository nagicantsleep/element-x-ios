//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

/// Wire constants for friend-request DM markers (ADR 0016), file-local to this file because it is
/// also compiled into the NSE target, which doesn't include the friends feature. Web still sends
/// the legacy `m.friend_request` msgtype; wire v2 instead sends `m.text` with the custom
/// `io.nagi.friend_request` formatted-body format, because the Rust SDK's default event filter
/// drops unknown msgtypes before they ever reach the timeline.
nonisolated let friendRequestMarkerMsgType = "m.friend_request"
nonisolated let friendRequestMarkerFormat = "io.nagi.friend_request"

/// The one friend-request detection rule used by every site (timeline render, room list preview,
/// notification content, incoming-request observer): a legacy `m.friend_request` msgtype or a wire
/// v2 `m.text` carrying the marker format, which the FFI delivers as `MessageFormat.unknown`.
nonisolated extension MessageType {
    var isFriendRequestMarker: Bool {
        switch self {
        case .other(let msgtype, _):
            return msgtype == friendRequestMarkerMsgType
        case .text(let content):
            guard case let .unknown(format) = content.formatted?.format else { return false }
            return format == friendRequestMarkerFormat
        default:
            return false
        }
    }
}

nonisolated struct RoomMessageEventStringBuilder {
    enum Style {
        /// Plain: no prefix, no special text treatment
        /// Shown in push notifications and thread lists
        case plain
        /// Strings show on the room list as the last message
        /// The sender will be prefixed in bold
        case senderPrefixed
        /// Events pinned to the banner on the top of the timeline
        /// The message type will be prefixed in bold
        case typeBolded
    }
    
    let attributedStringBuilder: AttributedStringBuilderProtocol
    let style: Style
    
    func buildAttributedString(for messageType: MessageType, senderDisplayName: String, isOutgoing: Bool) -> AttributedString {
        let message: AttributedString
        switch messageType {
        case .emote(content: let content):
            if let attributedMessage = attributedMessageFrom(formattedBody: content.formatted) {
                return AttributedString(L10n.commonEmote(senderDisplayName, String(attributedMessage.characters)))
            } else {
                return AttributedString(L10n.commonEmote(senderDisplayName, content.body))
            }
        case .audio(content: let content):
            let isVoiceMessage = content.voice != nil
            var content = AttributedString(isVoiceMessage ? L10n.commonVoiceMessage : L10n.commonAudio)
            if style == .typeBolded {
                content.bold()
            }
            message = content
        case .image(let content):
            message = buildMessage(for: style, caption: content.caption, type: L10n.commonImage)
        case .video(let content):
            message = buildMessage(for: style, caption: content.caption, type: L10n.commonVideo)
        case .file(let content):
            message = buildMessage(for: style, caption: content.caption, type: L10n.commonFile)
        case .location:
            var content = AttributedString(L10n.commonSharedLocation)
            if style == .typeBolded {
                content.bold()
            }
            message = content
        case .notice(content: let content):
            if let attributedMessage = attributedMessageFrom(formattedBody: content.formatted) {
                message = attributedMessage
            } else {
                message = AttributedString(content.body)
            }
        case .text(let content):
            // ADR 0016: wire v2 friend-request markers are `m.text` with a custom format; render
            // the localized label as plain text, never the formatted body as HTML.
            if MessageType.text(content: content).isFriendRequestMarker {
                message = AttributedString(localizedFriendRequestLabel())
            } else if let attributedMessage = attributedMessageFrom(formattedBody: content.formatted) {
                message = attributedMessage
            } else {
                message = AttributedString(content.body)
            }
        case .gallery(let content):
            message = buildGalleryMessage(for: style, content: content)
        case .other(let msgtype, let body):
            // ADR 0016: legacy `m.friend_request` markers render with a localized display label;
            // the sent body stays English for interoperability.
            message = AttributedString(msgtype == friendRequestMarkerMsgType
                ? localizedFriendRequestLabel()
                : body)
        }
        
        if style == .senderPrefixed {
            return prefix(message, with: isOutgoing ? L10n.commonYou : senderDisplayName)
        } else {
            return message
        }
    }
    
    func buildAttributedStringForLiveLocation(senderDisplayName: String, isOutgoing: Bool) -> AttributedString {
        var message = AttributedString(L10n.commonSharedLiveLocation)
        if style == .typeBolded {
            message.bold()
        }
        
        if style == .senderPrefixed {
            return prefix(message, with: isOutgoing ? L10n.commonYou : senderDisplayName)
        } else {
            return message
        }
    }
    
    /// A gallery's body is its caption. Notifications fall back to counting the attachments when
    /// there isn't one, whilst elsewhere it is treated as any other media's caption.
    private func buildGalleryMessage(for style: Style, content: GalleryMessageContent) -> AttributedString {
        switch style {
        case .plain:
            if content.body.isBlank {
                AttributedString(L10n.notificationGalleryBody(content.itemtypes.count))
            } else {
                AttributedString(content.body)
            }
        case .senderPrefixed, .typeBolded:
            buildMessage(for: style, caption: content.body, type: L10n.commonGallery)
        }
    }
    
    private func buildMessage(for style: Style, caption: String?, type: String) -> AttributedString {
        guard let caption, !caption.isBlank else {
            return AttributedString(type)
        }
        
        if style == .typeBolded {
            return prefix(AttributedString(caption), with: type)
        } else {
            return AttributedString("\(type) - \(caption)")
        }
    }
    
    /// The localized friend-request label. The main app resolves the Untranslated table; the NSE
    /// falls back to the English body. Markers are detected by `MessageType.isFriendRequestMarker`
    /// (legacy msgtype or wire v2 format; ADR 0016).
    private func localizedFriendRequestLabel() -> String {
        #if IS_MAIN_APP
        UntranslatedL10n.friendRequestDisplayBody
        #else
        // The NSE doesn't compile the friends feature or the Untranslated strings table; mirror
        // the wire body, which stays English for interoperability.
        "👋 Friend request"
        #endif
    }
    
    private func prefix(_ eventSummary: AttributedString, with textToBold: String) -> AttributedString {
        let attributedEventSummary = AttributedString(eventSummary.string.trimmingCharacters(in: .whitespacesAndNewlines))
        
        var attributedPrefix = AttributedString(textToBold + ":")
        attributedPrefix.bold()
        
        // Don't include the message body in the markdown otherwise it makes tappable links.
        return attributedPrefix + " " + attributedEventSummary
    }
    
    private func attributedMessageFrom(formattedBody: FormattedBody?) -> AttributedString? {
        formattedBody.flatMap { attributedStringBuilder.fromHTML($0.body) }
    }
}
