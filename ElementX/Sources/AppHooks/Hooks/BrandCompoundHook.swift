//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound

/// Applies the persisted `BrandTheme` to the Compound colour tokens at runtime.
///
/// Only the public `override(_:with:)` API is used, so the generated token definitions are left
/// untouched. The hook is a no-op (clears all brand overrides) when the Default theme is selected.
nonisolated struct BrandCompoundHook: CompoundHookProtocol {
    let appSettings: AppSettings
    
    @MainActor
    func override(colors: CompoundColors, uiColors: CompoundUIColors) {
        // Clear any overrides from a previously selected brand so that switching brands (or
        // returning to the Default theme) restores the original Compound tokens.
        for keyPath in BrandTheme.allColorKeyPaths {
            colors.override(keyPath, with: nil)
        }
        for keyPath in BrandTheme.allUIColorKeyPaths {
            uiColors.override(keyPath, with: nil)
        }
        
        for (keyPath, color) in appSettings.brandTheme.colorOverrides {
            colors.override(keyPath, with: color)
        }
        for (keyPath, color) in appSettings.brandTheme.uiColorOverrides {
            uiColors.override(keyPath, with: color)
        }
    }
}
