//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import SwiftUI
import Testing
import UIKit

/// ADR 0016 per-theme layout knobs for the Default/Z/L themes.
final class BrandLayoutTests {
    /// SwiftUI `Color`/`UIColor` equality doesn't hold for predicate-based dynamic colours (each
    /// instance wraps its own provider closure), so knobs are compared through their resolved
    /// RGBA in light and dark traits instead.
    private func expectResolvedEqual(_ color: Color?, _ light: String, _ dark: String,
                                     sourceLocation: SourceLocation = #_sourceLocation) {
        guard let color else {
            Issue.record("Expected a colour", sourceLocation: sourceLocation)
            return
        }
        
        // A dynamic colour resolves to its light variant under light traits and its dark variant
        // under dark traits; the fixed hexes are matched trait-for-trait.
        expectResolvedEqual(UIColor(color), BrandTheme.uiColor(light), traits: UITraitCollection(userInterfaceStyle: .light), sourceLocation: sourceLocation)
        expectResolvedEqual(UIColor(color), BrandTheme.uiColor(dark), traits: UITraitCollection(userInterfaceStyle: .dark), sourceLocation: sourceLocation)
    }
    
    private func expectResolvedEqual(_ color: UIColor?, _ expected: UIColor, traits: UITraitCollection,
                                     sourceLocation: SourceLocation = #_sourceLocation) {
        guard let color,
              let rgba = color.resolvedColor(with: traits).rgbaComponents(),
              let expectedRgba = expected.resolvedColor(with: traits).rgbaComponents() else {
            Issue.record("Couldn't resolve colour", sourceLocation: sourceLocation)
            return
        }
        
        #expect(rgba == expectedRgba, sourceLocation: sourceLocation)
    }
    
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
        
        expectResolvedEqual(layout.chatBackgroundColor, "#E2E9F1", "#0E1621")
        expectResolvedEqual(layout.outgoingBubbleColor, "#E5EFFF", "#14263D")
        expectResolvedEqual(layout.outgoingTextColor, "#081C36", "#E9EDF2")
        expectResolvedEqual(layout.incomingBubbleColor, "#FFFFFF", "#1F2A36")
        #expect(layout.bubbleCornerRadius == 12)
        #expect(layout.homeHeaderKind == .zBar)
        #expect(layout.isChatBarAccented == true)
        #expect(layout.readIndicatorStyle == .stockAvatars)
        expectResolvedEqual(layout.tabAccentColor.map(Color.init(uiColor:)), "#0068FF", "#4D94FF")
        #expect(layout.showsTabCountBadges == true)
    }
    
    /// L (LINE-like) knob values from the ADR table.
    @Test
    func lLayoutKnobs() {
        let layout = BrandLayout.layout(for: .l)
        
        expectResolvedEqual(layout.chatBackgroundColor, "#8CABD8", "#0E1621")
        expectResolvedEqual(layout.outgoingBubbleColor, "#85E249", "#2F6F3E")
        expectResolvedEqual(layout.outgoingTextColor, "#1A1A1A", "#E9EDF2")
        expectResolvedEqual(layout.incomingBubbleColor, "#FFFFFF", "#222821")
        #expect(layout.bubbleCornerRadius == 18)
        #expect(layout.homeHeaderKind == .lPlain)
        #expect(layout.isChatBarAccented == false)
        #expect(layout.readIndicatorStyle == .textLabel)
        expectResolvedEqual(layout.tabAccentColor.map(Color.init(uiColor:)), "#06C755", "#33D377")
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

private extension UIColor {
    /// Quantised 8-bit RGBA components for stable equality across colour spaces.
    func rgbaComponents() -> [Int]? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        let srgb = UIColor { traits in
            let base = self.resolvedColor(with: traits)
            var (r, g, b, a) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
            base.getRed(&r, green: &g, blue: &b, alpha: &a)
            return UIColor(red: r, green: g, blue: b, alpha: a)
        }
        
        guard srgb.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(&red,
                                                                                             green: &green,
                                                                                             blue: &blue,
                                                                                             alpha: &alpha) else {
            return nil
        }
        
        return [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
    }
}
