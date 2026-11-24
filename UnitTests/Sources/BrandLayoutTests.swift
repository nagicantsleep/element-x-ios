//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import SwiftUI
import Testing

/// ADR 0016 per-theme layout knobs for the Default/Z/L themes.
final class BrandLayoutTests {
    @Test
    func defaultLayoutIsStock() {
        let layout = BrandLayout.layout(for: .defaultTheme)
        
        #expect(layout.chatBackgroundColor == nil)
        #expect(layout.outgoingBubbleColor == nil)
        #expect(layout.outgoingTextColor == nil)
        #expect(layout.incomingBubbleColor == nil)
        #expect(layout.bubbleCornerRadius == nil)
        #expect(layout.homeHeaderKind == .stock)
        #expect(layout.isChatBarAccented == false)
        #expect(layout.readIndicatorStyle == .stockAvatars)
        #expect(layout.tabAccentColor == nil)
        #expect(layout.showsTabCountBadges == nil)
    }
    
    /// Z (Zalo-like) knob values from the ADR table.
    @Test
    func zLayoutKnobs() {
        let layout = BrandLayout.layout(for: .z)
        
        #expect(layout.chatBackgroundColor == BrandTheme.color("#E2E9F1", "#0E1621"))
        #expect(layout.outgoingBubbleColor == BrandTheme.color("#E5EFFF", "#14263D"))
        #expect(layout.outgoingTextColor == BrandTheme.color("#081C36", "#E9EDF2"))
        #expect(layout.incomingBubbleColor == BrandTheme.color("#FFFFFF", "#1F2A36"))
        #expect(layout.bubbleCornerRadius == 12)
        #expect(layout.homeHeaderKind == .zBar)
        #expect(layout.isChatBarAccented == true)
        #expect(layout.readIndicatorStyle == .stockAvatars)
        #expect(layout.tabAccentColor == BrandTheme.uiColor("#0068FF", "#4D94FF"))
        #expect(layout.showsTabCountBadges == true)
    }
    
    /// L (LINE-like) knob values from the ADR table.
    @Test
    func lLayoutKnobs() {
        let layout = BrandLayout.layout(for: .l)
        
        #expect(layout.chatBackgroundColor == BrandTheme.color("#8CABD8", "#0E1621"))
        #expect(layout.outgoingBubbleColor == BrandTheme.color("#85E249", "#2F6F3E"))
        #expect(layout.outgoingTextColor == BrandTheme.color("#1A1A1A", "#E9EDF2"))
        #expect(layout.incomingBubbleColor == BrandTheme.color("#FFFFFF", "#222821"))
        #expect(layout.bubbleCornerRadius == 18)
        #expect(layout.homeHeaderKind == .lPlain)
        #expect(layout.isChatBarAccented == false)
        #expect(layout.readIndicatorStyle == .textLabel)
        #expect(layout.tabAccentColor == BrandTheme.uiColor("#06C755", "#33D377"))
        #expect(layout.showsTabCountBadges == true)
    }
    
    /// A layout is derived from whatever theme the view state carries.
    @Test
    func layoutFollowsTheme() {
        #expect(BrandLayout.layout(for: .z) == BrandLayout.z)
        #expect(BrandLayout.layout(for: .l) == BrandLayout.l)
        #expect(BrandLayout.layout(for: .defaultTheme) == BrandLayout.default)
    }
}
