//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// The languages offered by the in-app language picker.
///
/// The fork ships Untranslated tables and the main Localizable table for English,
/// Japanese and Vietnamese; the OS per-app language row drives the same set.
///
/// Keep this file free of UI/dependency code: the NSE target compiles it together with
/// the rest of `Application/Settings`.
nonisolated enum LanguageSetting: CaseIterable, Equatable, Hashable {
    case systemDefault
    case english
    case japanese
    case vietnamese
    
    /// The language code persisted in the `AppleLanguages` user default, or `nil` to let
    /// the OS resolve the language (device language / per-app language row).
    var languageCode: String? {
        switch self {
        case .systemDefault: nil
        case .english: "en"
        case .japanese: "ja"
        case .vietnamese: "vi"
        }
    }
    
    /// Matches an `AppleLanguages` entry (which can be regional, e.g. `en-US`) by its
    /// primary language code. Returns `nil` for languages the fork doesn't offer.
    init?(identifier: String) {
        let primaryLanguageCode = Locale(identifier: identifier).language.languageCode?.identifier ?? identifier
        switch primaryLanguageCode {
        case "en": self = .english
        case "ja": self = .japanese
        case "vi": self = .vietnamese
        default: return nil
        }
    }
}

/// Persists the in-app language choice in the `AppleLanguages` user default.
///
/// `AppleLanguages` is the same preference the iOS per-app language row maintains, so the
/// in-app picker and the system row stay in agreement, and both are read by
/// `Bundle.app.preferredLocalizations` (driving `L10n.tr` and `UntranslatedL10n.tr`) on the
/// next launch. `UserDefaults.standard` is required here: `Bundle` resolves
/// `preferredLocalizations` from the app's standard defaults domain, not the app group.
nonisolated enum LanguageSettingsStore {
    static let appleLanguagesKey = "AppleLanguages"
    
    /// Reads what the OS currently applies: the stored choice if present, otherwise what
    /// `preferredLocalizations` resolves to (covers the system per-app language row), so the
    /// picker never lies about the effective language. Falls back to system default.
    static func current(defaults: UserDefaults = .standard, bundle: Bundle = .app) -> LanguageSetting {
        if let storedIdentifier = defaults.stringArray(forKey: appleLanguagesKey)?.first,
           let stored = LanguageSetting(identifier: storedIdentifier) {
            return stored
        }
        
        if let resolvedIdentifier = bundle.effectivePreferredLocalizations.first,
           let resolved = LanguageSetting(identifier: resolvedIdentifier) {
            return resolved
        }
        
        return .systemDefault
    }
    
    /// Persists the choice; the new language applies on the next app launch.
    /// Selecting system default removes the key entirely so the OS resolves the language again.
    static func set(_ setting: LanguageSetting, defaults: UserDefaults = .standard) {
        guard let languageCode = setting.languageCode else {
            defaults.removeObject(forKey: appleLanguagesKey)
            return
        }
        
        defaults.set([languageCode], forKey: appleLanguagesKey)
    }
    
    /// Whether picking `picked` changes the language the OS currently applies, meaning a
    /// restart is needed for the selection to take effect.
    ///
    /// System default only changes something when an in-app override is being dropped, which
    /// can't be detected through `stringArray(forKey:)` — a missing app-domain entry reads
    /// through to the global `AppleLanguages` preference — hence the app-domain name.
    static func needsRestart(for picked: LanguageSetting,
                             defaults: UserDefaults = .standard,
                             bundle: Bundle = .app,
                             appDomainName: String? = nil) -> Bool {
        if picked == .systemDefault {
            return storedOverride(defaults: defaults, appDomainName: appDomainName) != nil
        }
        
        let effectiveIdentifier = bundle.effectivePreferredLocalizations.first ?? ""
        guard let pickedCode = picked.languageCode else { return false }
        
        return primaryLanguageCode(of: pickedCode) != primaryLanguageCode(of: effectiveIdentifier)
    }
    
    /// The `AppleLanguages` value stored in `defaults`' own domain, ignoring the global fallback.
    ///
    /// `appDomainName` defaults to the main bundle identifier, which backs `UserDefaults.standard`.
    static func storedOverride(defaults: UserDefaults = .standard, appDomainName: String? = nil) -> [String]? {
        guard let domainName = appDomainName ?? Bundle.main.bundleIdentifier else { return nil }
        
        return defaults.persistentDomain(forName: domainName)?[appleLanguagesKey] as? [String]
    }
    
    private static func primaryLanguageCode(of identifier: String) -> String {
        Locale(identifier: identifier).language.languageCode?.identifier ?? identifier
    }
}
