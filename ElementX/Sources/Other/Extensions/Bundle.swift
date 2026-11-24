//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import Synchronization

public nonisolated extension Bundle {
    /// The top-level bundle that contains the entire app.
    static var app: Bundle {
        var bundle = Bundle.main
        if bundle.bundleURL.pathExtension == "appex" {
            // Peel off two directory levels - MY_APP.app/PlugIns/MY_APP_EXTENSION.appex
            let url = bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            if let otherBundle = Bundle(url: url) {
                bundle = otherBundle
            }
        }
        return bundle
    }
    
    /// The effective localizations: the test override when set, otherwise the receiver's own.
    var effectivePreferredLocalizations: [String] {
        Self.overridePreferredLocalizations ?? preferredLocalizations
    }
    
    // MARK: - Localisation
    
    /// Overrides `Bundle.app.preferredLocalizations` for testing translations since this is
    /// only for testing, and is changed at runtime only in tests, it's fine to keep as `nonisolated(unsafe)`
    nonisolated(unsafe) static var overrideLocalizations: [String]?
    
    /// Overrides `preferredLocalizations` resolution (both on `Bundle.app` and on the bundles
    /// handed to `LanguageSettingsStore`), so tests can pin the effective OS language instead of
    /// depending on the machine the suite runs on. Only honoured when `overrideLocalizations`
    /// is `nil` so the two knobs never fight.
    nonisolated(unsafe) static var overridePreferredLocalizations: [String]?
    
    private static let cachedBundles = Mutex<[String: Bundle]>([:])
    
    /// Get an lproj language bundle from the receiver bundle.
    /// - Parameter language: The language to try to load.
    /// - Returns: The lproj bundle if found otherwise nil.
    static func lprojBundle(for language: String) -> Bundle? {
        if let bundle = cachedValue(forKey: language) {
            return bundle
        }
        
        guard let lprojURL = Bundle.app.url(forResource: language, withExtension: "lproj") else {
            return nil
        }
        
        let bundle = Bundle(url: lprojURL)
        
        cacheValue(bundle, forKey: language)
        
        return bundle
    }
    
    // MARK: - Private
    
    private static func cacheValue(_ value: Bundle?, forKey key: String) {
        cachedBundles.withLock { $0[key] = value }
    }
    
    private static func cachedValue(forKey key: String) -> Bundle? {
        cachedBundles.withLock { $0[key] }
    }
}
