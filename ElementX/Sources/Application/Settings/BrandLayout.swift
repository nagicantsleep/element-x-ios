//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI
import UIKit

/// The per-theme presentation knobs from ADR 0016 (Z ≈ Zalo, L ≈ LINE).
///
/// Every theme-dependent value used by the fork's screens comes from this type — screens read
/// knobs instead of scattering `switch theme` checks, so the upstream merge surface stays bounded
/// to this one file plus `BrandTheme.swift`. The Default theme yields stock rendering (`nil`
/// overrides / stock values).
///
/// Light values are taken from the ADR table; dark values keep stock dark surfaces with the brand
/// accent, never a bright light slab.
///
/// Keep this file free of UI-only dependencies: `Application/Settings` is compiled into the NSE
/// target too.
nonisolated struct BrandLayout: Equatable {
    // MARK: - Chat
    
    /// The timeline background, or `nil` for Compound's default canvas.
    var chatBackgroundColor: Color?
    /// The "from me" bubble background, or `nil` for Compound's default.
    var outgoingBubbleColor: Color?
    /// The text colour on the outgoing bubble, or `nil` for the stock (accent-contrast) text.
    var outgoingTextColor: Color?
    /// The "from others" bubble background, or `nil` for Compound's default.
    var incomingBubbleColor: Color?
    /// The message bubble corner radius, or `nil` to keep Compound's 18.
    var bubbleCornerRadius: CGFloat?
    
    // MARK: - Room list header
    
    /// How the room list (Home) header is presented.
    var homeHeaderKind: HomeHeaderKind = .stock
    
    /// Room list header presentations (ADR 0016).
    enum HomeHeaderKind {
        /// Stock Element: large title in the nav bar, avatar + actions on the trailing side.
        case stock
        /// Z: solid accent bar under the status bar; search field inside it (white 20% pill,
        /// white icon/placeholder); white QR and "+" actions; no large title.
        case zBar
        /// L: plain canvas; bold title left; plain (not circular) action icons right;
        /// grey `#F5F6F7` search pill below.
        case lPlain
    }
    
    // MARK: - Chat top bar
    
    /// Whether the chat (room) navigation bar is painted in the brand accent with white content.
    /// Only applied in light mode; dark mode keeps the stock bar.
    var isChatBarAccented = false
    
    // MARK: - Read indicator
    
    /// ADR 0016: "Text label where stock shows receipts" for L; `.stockAvatars` (Default/Z)
    /// keeps the avatar stack. The label strings live in the Untranslated tables and are
    /// resolved by the read-receipts view (this file is compiled into the NSE too).
    var readIndicatorStyle: ReadIndicatorStyle = .stockAvatars
    
    enum ReadIndicatorStyle {
        /// Stock avatar stack where receipts render.
        case stockAvatars
        /// Text label: 1:1 "Read" / "Đã xem" / "既読"; group "Read N" / "Đã xem N" / "既読 N".
        case textLabel
    }
    
    // MARK: - Tab bar
    
    /// The accent colour used for the selected tab and (indirectly) the tab bar tint, or `nil`
    /// for the stock tint.
    var tabAccentColor: UIColor?
    /// Whether the Messages/Contacts tabs show red count badges (matching Android's
    /// HomeNavigationBar), or `nil` for the stock badge behaviour.
    var showsTabCountBadges: Bool?
    
    // MARK: - Factories
    
    /// The layout for a resolved brand theme.
    static func layout(for theme: BrandTheme) -> BrandLayout {
        switch theme {
        case .defaultTheme:
            .default
        case .z:
            .z
        case .l:
            .l
        }
    }
    
    /// Stock rendering.
    static let `default` = BrandLayout()
    
    /// Z theme (Zalo-like), light values from the ADR table.
    static let z = BrandLayout(chatBackgroundColor: BrandTheme.color("#E2E9F1", "#0E1621"),
                               outgoingBubbleColor: BrandTheme.color("#E5EFFF", "#14263D"),
                               outgoingTextColor: BrandTheme.color("#081C36", "#E9EDF2"),
                               incomingBubbleColor: BrandTheme.color("#FFFFFF", "#1F2A36"),
                               bubbleCornerRadius: 12,
                               homeHeaderKind: .zBar,
                               isChatBarAccented: true,
                               readIndicatorStyle: .stockAvatars,
                               tabAccentColor: BrandTheme.uiColor("#0068FF", "#4D94FF"),
                               showsTabCountBadges: true)
    
    /// L theme (LINE-like), light values from the ADR table.
    static let l = BrandLayout(chatBackgroundColor: BrandTheme.color("#8CABD8", "#0E1621"),
                               outgoingBubbleColor: BrandTheme.color("#85E249", "#2F6F3E"),
                               outgoingTextColor: BrandTheme.color("#1A1A1A", "#E9EDF2"),
                               incomingBubbleColor: BrandTheme.color("#FFFFFF", "#222821"),
                               bubbleCornerRadius: 18,
                               homeHeaderKind: .lPlain,
                               isChatBarAccented: false,
                               readIndicatorStyle: .textLabel,
                               tabAccentColor: BrandTheme.uiColor("#06C755", "#33D377"),
                               showsTabCountBadges: true)
}
