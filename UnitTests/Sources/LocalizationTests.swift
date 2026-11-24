//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

final class LocalizationTests {
    /// Serialises tests that mutate the process-wide localisation overrides: Swift Testing
    /// runs suites concurrently and the overrides are `nonisolated(unsafe)` globals shared
    /// with LanguageSettingsTests.
    private static let overridesLock = NSLock()
    
    private func withOverrideLocalizations(_ languages: [String]?, _ body: () -> Void) {
        Self.overridesLock.lock()
        defer { Self.overridesLock.unlock() }
        
        Bundle.overrideLocalizations = languages
        body()
        Bundle.overrideLocalizations = nil
    }
    
    deinit {
        Bundle.overrideLocalizations = nil
    }
    
    /// Test ElementL10n considers app language changes
    @Test
    func appLanguage() {
        withOverrideLocalizations(["en"]) {
            #expect(L10n.testLanguageIdentifier == "en")
        }
        
        withOverrideLocalizations(["it"]) {
            #expect(L10n.testLanguageIdentifier == "it")
        }
    }
    
    /// Test fallback language for a language not supported at all
    @Test
    func fallbackOnNotSupportedLanguage() {
        //  set app language to something Element don't support at all (chose non existing identifier)
        withOverrideLocalizations(["xx"]) {
            #expect(L10n.testLanguageIdentifier == "en")
        }
    }
    
    /// Test fallback language for a language supported but poorly translated
    @Test
    func fallbackOnNotTranslatedKey() {
        //  set app language to something Element supports but use a key that is not translated (we have a key that should never be translated)
        withOverrideLocalizations(["it"]) {
            #expect(L10n.testLanguageIdentifier == "it")
            #expect(L10n.testUntranslatedDefaultLanguageIdentifier == "en")
        }
    }
    
    /// Test plurals that ElementL10n considers app language changes
    @Test
    func plurals() {
        withOverrideLocalizations(["en"]) {
            #expect(L10n.commonMemberCount(1) == "1 Member")
            #expect(L10n.commonMemberCount(2) == "2 Members")
        }
        
        withOverrideLocalizations(["it"]) {
            #expect(L10n.commonMemberCount(1) == "1 Membro")
            #expect(L10n.commonMemberCount(2) == "2 Membri")
        }
    }
    
    /// Test plurals fallback language for a language not supported at all
    @Test
    func pluralsFallbackOnNotSupportedLanguage() {
        //  set app language to something Element don't support at all ("invalid identifier")
        withOverrideLocalizations(["xx"]) {
            #expect(L10n.commonMemberCount(1) == "1 Member")
            #expect(L10n.commonMemberCount(2) == "2 Members")
        }
    }
    
    /// Test untranslated strings
    @Test
    func untranslated() {
        #expect(UntranslatedL10n.untranslated == "Untranslated")
        #expect(UntranslatedL10n.untranslatedPlural(1) == "One untranslated item")
        #expect(UntranslatedL10n.untranslatedPlural(5) == "5 untranslated items")
    }
    
    /// Test the Untranslated table resolves in the device language when translated
    @Test
    func untranslatedResolvesInDeviceLanguage() {
        withOverrideLocalizations(["vi"]) {
            #expect(UntranslatedL10n.screenFriendsTitle == "Bạn bè")
        }
        
        withOverrideLocalizations(["ja"]) {
            #expect(UntranslatedL10n.screenFriendsTitle == "フレンド")
        }
    }
    
    /// Test the Untranslated table falls back to English when the language doesn't translate the key
    @Test
    func untranslatedFallsBackToEnglishWhenLanguageTableMissing() {
        // Vietnamese ships a table but only for the fork's own keys
        withOverrideLocalizations(["vi"]) {
            #expect(UntranslatedL10n.untranslated == "Untranslated")
        }
        
        // French ships no Untranslated table at all
        withOverrideLocalizations(["fr"]) {
            #expect(UntranslatedL10n.screenFriendsTitle == "Friends")
            // en fallback must forward format args (plurals go through tr with an arg)
            #expect(UntranslatedL10n.untranslatedPlural(5) == "5 untranslated items")
        }
    }
    
    /// Test untranslated strings default to English when the OS language isn't overridden by
    /// the test itself. Hermetic: the suite pins the device language instead of relying on
    /// the machine resolving to English.
    @Test
    func untranslatedDefaultsToEnglish() {
        Self.overridesLock.lock()
        defer { Self.overridesLock.unlock() }
        
        Bundle.overrideLocalizations = nil
        Bundle.overridePreferredLocalizations = ["en"]
        defer { Bundle.overridePreferredLocalizations = nil }
        
        #expect(UntranslatedL10n.screenFriendsTitle == "Friends")
    }
}
