//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import Foundation
import SwiftUI
import UIKit

/// Used to specify the user's app specific brand theme preference.
///
/// A brand theme is applied at runtime by overriding a small set of Compound colour tokens via the
/// public `override(_:with:)` API - the generated token definitions are never modified. The token
/// values are taken from `config/themes/z.json` and `config/themes/l.json`.
///
/// Every Compound token is an adaptive asset (white in light mode, near-black in dark mode), so each
/// override carries a light **and** a dark value. A single fixed colour would force a light surface
/// onto dark mode and break it.
nonisolated enum BrandTheme: String, CaseIterable, Codable {
    case defaultTheme
    case z
    case l
    
    var name: String {
        switch self {
        case .defaultTheme:
            return "Default"
        case .z:
            return "Z theme"
        case .l:
            return "L theme"
        }
    }
    
    /// The Compound colour-token overrides to apply to `CompoundColors` for this brand.
    var colorOverrides: [(KeyPath<CompoundColorTokens, Color>, Color)] {
        switch self {
        case .defaultTheme:
            return []
        case .z:
            return Self.zColorOverrides
        case .l:
            return Self.lColorOverrides
        }
    }
    
    /// The Compound colour-token overrides to apply to `CompoundUIColors` for this brand.
    var uiColorOverrides: [(KeyPath<CompoundUIColorTokens, UIColor>, UIColor)] {
        switch self {
        case .defaultTheme:
            return []
        case .z:
            return Self.zUIColorOverrides
        case .l:
            return Self.lUIColorOverrides
        }
    }
    
    /// The "from me" bubble colour for this brand, or `nil` to keep Compound's default.
    ///
    /// Compound's bubble tokens (`_bgBubbleIncoming` / `_bgBubbleOutgoing`) are plain stored
    /// properties on `CompoundColors`, not `CompoundColorTokens` members, so they bypass the
    /// runtime override dictionary and cannot be retinted through `override(_:with:)`. The bubble
    /// styler therefore reads this value directly instead.
    var outgoingBubbleColor: Color? {
        switch self {
        case .defaultTheme:
            return nil
        case .z:
            return Color(uiColor: Self.uiColor("#E6F0FF", "#14263D"))
        case .l:
            return Color(uiColor: Self.uiColor("#E6F9EE", "#12301F"))
        }
    }
    
    /// Every colour key path that any brand may override.
    ///
    /// Used to clear stale overrides when the selection changes (including a return to `.defaultTheme`),
    /// so that switching brands at runtime doesn't leak the previous brand's colours.
    static var allColorKeyPaths: [KeyPath<CompoundColorTokens, Color>] {
        var keyPaths = zColorOverrides.map(\.0)
        for keyPath in lColorOverrides.map(\.0) where !keyPaths.contains(keyPath) {
            keyPaths.append(keyPath)
        }
        return keyPaths
    }
    
    /// Every UI colour key path that any brand may override.
    static var allUIColorKeyPaths: [KeyPath<CompoundUIColorTokens, UIColor>] {
        var keyPaths = zUIColorOverrides.map(\.0)
        for keyPath in lUIColorOverrides.map(\.0) where !keyPaths.contains(keyPath) {
            keyPaths.append(keyPath)
        }
        return keyPaths
    }
}

// MARK: - Token override tables

nonisolated extension BrandTheme {
    static var zColorOverrides: [(KeyPath<CompoundColorTokens, Color>, Color)] {
        [
            (\CompoundColorTokens.bgAccentRest, color("#0068FF", "#0068FF")),
            (\CompoundColorTokens.bgActionPrimaryRest, color("#0068FF", "#0068FF")),
            (\CompoundColorTokens.bgActionPrimaryHovered, color("#0057D6", "#0057D6")),
            (\CompoundColorTokens.bgActionPrimaryPressed, color("#0046AD", "#0046AD")),
            (\CompoundColorTokens.bgActionSecondaryRest, color("#E6F0FF", "#1C2A3A")),
            (\CompoundColorTokens.bgActionSecondaryHovered, color("#D6E6FF", "#24374B")),
            (\CompoundColorTokens.textActionAccent, color("#0068FF", "#66A5FF")),
            (\CompoundColorTokens.iconAccentPrimary, color("#0068FF", "#4D94FF")),
            (\CompoundColorTokens.iconAccentTertiary, color("#0068FF", "#66A5FF")),
            (\CompoundColorTokens.borderInteractivePrimary, color("#0068FF", "#4D94FF")),
            (\CompoundColorTokens.borderFocused, color("#0068FF", "#4D94FF")),
            (\CompoundColorTokens.bgCriticalPrimary, color("#E5484D", "#E5484D")),
            (\CompoundColorTokens.bgCriticalHovered, color("#C93B40", "#C93B40")),
            (\CompoundColorTokens.bgSuccessSubtle, color("#E7F7EF", "#10321F")),
            (\CompoundColorTokens.textPrimary, color("#081C36", "#E9EDF2")),
            (\CompoundColorTokens.textSecondary, color("#7589A3", "#8A9BA8")),
            (\CompoundColorTokens.bgCanvasDefault, color("#FFFFFF", "#0E1621")),
            (\CompoundColorTokens.bgSubtlePrimary, color("#F7F9FC", "#17212B")),
            (\CompoundColorTokens.bgSubtleSecondary, color("#F2F4F7", "#1F2A36")),
            (\CompoundColorTokens.separatorPrimary, color("#E5EAF0", "#2A3947"))
        ]
    }
    
    static var lColorOverrides: [(KeyPath<CompoundColorTokens, Color>, Color)] {
        [
            (\CompoundColorTokens.bgAccentRest, color("#06C755", "#06C755")),
            (\CompoundColorTokens.bgActionPrimaryRest, color("#06C755", "#06C755")),
            (\CompoundColorTokens.bgActionPrimaryHovered, color("#05A948", "#05A948")),
            (\CompoundColorTokens.bgActionPrimaryPressed, color("#048A3B", "#048A3B")),
            (\CompoundColorTokens.bgActionSecondaryRest, color("#E6F9EE", "#1C2A22")),
            (\CompoundColorTokens.bgActionSecondaryHovered, color("#D3F3E0", "#24352B")),
            (\CompoundColorTokens.textActionAccent, color("#04A445", "#33D377")),
            (\CompoundColorTokens.iconAccentPrimary, color("#06C755", "#06C755")),
            (\CompoundColorTokens.iconAccentTertiary, color("#04A445", "#33D377")),
            (\CompoundColorTokens.borderInteractivePrimary, color("#06C755", "#06C755")),
            (\CompoundColorTokens.borderFocused, color("#06C755", "#06C755")),
            (\CompoundColorTokens.bgCriticalPrimary, color("#FA4B42", "#FA4B42")),
            (\CompoundColorTokens.bgCriticalHovered, color("#D93E36", "#D93E36")),
            (\CompoundColorTokens.bgSuccessSubtle, color("#E6F9EE", "#10321F")),
            (\CompoundColorTokens.textPrimary, color("#1A1A1A", "#E9EDF2")),
            (\CompoundColorTokens.textSecondary, color("#6E6E6E", "#8A9BA8")),
            (\CompoundColorTokens.bgCanvasDefault, color("#FFFFFF", "#10140F")),
            (\CompoundColorTokens.bgSubtlePrimary, color("#F5F6F7", "#191E18")),
            (\CompoundColorTokens.bgSubtleSecondary, color("#EBEDEF", "#222821")),
            (\CompoundColorTokens.separatorPrimary, color("#E6E6E6", "#2C332B"))
        ]
    }
    
    static var zUIColorOverrides: [(KeyPath<CompoundUIColorTokens, UIColor>, UIColor)] {
        [
            (\CompoundUIColorTokens.bgAccentRest, uiColor("#0068FF", "#0068FF")),
            (\CompoundUIColorTokens.bgActionPrimaryRest, uiColor("#0068FF", "#0068FF")),
            (\CompoundUIColorTokens.bgActionPrimaryHovered, uiColor("#0057D6", "#0057D6")),
            (\CompoundUIColorTokens.bgActionPrimaryPressed, uiColor("#0046AD", "#0046AD")),
            (\CompoundUIColorTokens.bgActionSecondaryRest, uiColor("#E6F0FF", "#1C2A3A")),
            (\CompoundUIColorTokens.bgActionSecondaryHovered, uiColor("#D6E6FF", "#24374B")),
            (\CompoundUIColorTokens.textActionAccent, uiColor("#0068FF", "#66A5FF")),
            (\CompoundUIColorTokens.iconAccentPrimary, uiColor("#0068FF", "#4D94FF")),
            (\CompoundUIColorTokens.iconAccentTertiary, uiColor("#0068FF", "#66A5FF")),
            (\CompoundUIColorTokens.borderInteractivePrimary, uiColor("#0068FF", "#4D94FF")),
            (\CompoundUIColorTokens.borderFocused, uiColor("#0068FF", "#4D94FF")),
            (\CompoundUIColorTokens.bgCriticalPrimary, uiColor("#E5484D", "#E5484D")),
            (\CompoundUIColorTokens.bgCriticalHovered, uiColor("#C93B40", "#C93B40")),
            (\CompoundUIColorTokens.bgSuccessSubtle, uiColor("#E7F7EF", "#10321F")),
            (\CompoundUIColorTokens.textPrimary, uiColor("#081C36", "#E9EDF2")),
            (\CompoundUIColorTokens.textSecondary, uiColor("#7589A3", "#8A9BA8")),
            (\CompoundUIColorTokens.bgCanvasDefault, uiColor("#FFFFFF", "#0E1621")),
            (\CompoundUIColorTokens.bgSubtlePrimary, uiColor("#F7F9FC", "#17212B")),
            (\CompoundUIColorTokens.bgSubtleSecondary, uiColor("#F2F4F7", "#1F2A36")),
            (\CompoundUIColorTokens.separatorPrimary, uiColor("#E5EAF0", "#2A3947"))
        ]
    }
    
    static var lUIColorOverrides: [(KeyPath<CompoundUIColorTokens, UIColor>, UIColor)] {
        [
            (\CompoundUIColorTokens.bgAccentRest, uiColor("#06C755", "#06C755")),
            (\CompoundUIColorTokens.bgActionPrimaryRest, uiColor("#06C755", "#06C755")),
            (\CompoundUIColorTokens.bgActionPrimaryHovered, uiColor("#05A948", "#05A948")),
            (\CompoundUIColorTokens.bgActionPrimaryPressed, uiColor("#048A3B", "#048A3B")),
            (\CompoundUIColorTokens.bgActionSecondaryRest, uiColor("#E6F9EE", "#1C2A22")),
            (\CompoundUIColorTokens.bgActionSecondaryHovered, uiColor("#D3F3E0", "#24352B")),
            (\CompoundUIColorTokens.textActionAccent, uiColor("#04A445", "#33D377")),
            (\CompoundUIColorTokens.iconAccentPrimary, uiColor("#06C755", "#06C755")),
            (\CompoundUIColorTokens.iconAccentTertiary, uiColor("#04A445", "#33D377")),
            (\CompoundUIColorTokens.borderInteractivePrimary, uiColor("#06C755", "#06C755")),
            (\CompoundUIColorTokens.borderFocused, uiColor("#06C755", "#06C755")),
            (\CompoundUIColorTokens.bgCriticalPrimary, uiColor("#FA4B42", "#FA4B42")),
            (\CompoundUIColorTokens.bgCriticalHovered, uiColor("#D93E36", "#D93E36")),
            (\CompoundUIColorTokens.bgSuccessSubtle, uiColor("#E6F9EE", "#10321F")),
            (\CompoundUIColorTokens.textPrimary, uiColor("#1A1A1A", "#E9EDF2")),
            (\CompoundUIColorTokens.textSecondary, uiColor("#6E6E6E", "#8A9BA8")),
            (\CompoundUIColorTokens.bgCanvasDefault, uiColor("#FFFFFF", "#10140F")),
            (\CompoundUIColorTokens.bgSubtlePrimary, uiColor("#F5F6F7", "#191E18")),
            (\CompoundUIColorTokens.bgSubtleSecondary, uiColor("#EBEDEF", "#222821")),
            (\CompoundUIColorTokens.separatorPrimary, uiColor("#E6E6E6", "#2C332B"))
        ]
    }
}

// MARK: - Hex parsing

private nonisolated extension BrandTheme {
    /// Builds an adaptive SwiftUI colour that resolves to `light` or `dark` with the interface style.
    static func color(_ light: String, _ dark: String) -> Color {
        Color(uiColor(light, dark))
    }
    
    /// Builds an adaptive UIKit colour that resolves to `light` or `dark` with the interface style.
    static func uiColor(_ light: String, _ dark: String) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light)
        }
    }
    
    static func uiColor(_ hex: String) -> UIColor {
        let components = rgbComponents(fromHex: hex)
        return UIColor(red: components.red, green: components.green, blue: components.blue, alpha: 1)
    }
    
    static func rgbComponents(fromHex hex: String) -> (red: Double, green: Double, blue: Double) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        
        guard value.count == 6, let number = UInt32(value, radix: 16) else {
            return (0, 0, 0)
        }
        
        return (Double((number >> 16) & 0xFF) / 255.0,
                Double((number >> 8) & 0xFF) / 255.0,
                Double(number & 0xFF) / 255.0)
    }
}
