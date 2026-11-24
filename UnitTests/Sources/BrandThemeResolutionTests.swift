//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

/// ADR 0016: the effective brand theme is resolved from the explicit picker choice first, and
/// otherwise from the effective app language (`vi` → Z, `ja` → L, else Default).
final class BrandThemeResolutionTests {
    // MARK: - Explicit choice wins
    
    /// Any explicit choice beats the language-derived default, even when the language suggests a
    /// different theme.
    @Test(arguments: [(choice: BrandTheme.defaultTheme, language: "vi", expected: BrandTheme.defaultTheme),
                      (choice: BrandTheme.defaultTheme, language: "ja", expected: BrandTheme.defaultTheme),
                      (choice: BrandTheme.z, language: "ja", expected: BrandTheme.z),
                      (choice: BrandTheme.l, language: "vi", expected: BrandTheme.l),
                      (choice: BrandTheme.z, language: nil, expected: BrandTheme.z),
                      (choice: BrandTheme.l, language: nil, expected: BrandTheme.l),
                      (choice: BrandTheme.defaultTheme, language: nil, expected: BrandTheme.defaultTheme)])
    func explicitChoiceBeatsLanguage(choice: BrandTheme, language: String?, expected: BrandTheme) {
        #expect(BrandTheme.resolve(choice: choice, preferredLocalization: language) == expected)
    }
    
    // MARK: - Language-derived default
    
    @Test
    func vietnameseResolvesToZ() {
        #expect(BrandTheme.resolve(choice: nil, preferredLocalization: "vi") == .z)
        #expect(BrandTheme.resolve(choice: nil, preferredLocalization: "vi-VN") == .z)
    }
    
    @Test
    func japaneseResolvesToL() {
        #expect(BrandTheme.resolve(choice: nil, preferredLocalization: "ja") == .l)
        #expect(BrandTheme.resolve(choice: nil, preferredLocalization: "ja-JP") == .l)
    }
    
    @Test
    func englishResolvesToDefault() {
        #expect(BrandTheme.resolve(choice: nil, preferredLocalization: "en") == .defaultTheme)
        #expect(BrandTheme.resolve(choice: nil, preferredLocalization: "en-GB") == .defaultTheme)
    }
    
    /// Any other language (or a missing localization) keeps the stock Default theme.
    @Test
    func otherLanguagesResolveToDefault() {
        #expect(BrandTheme.resolve(choice: nil, preferredLocalization: "fr") == .defaultTheme)
        #expect(BrandTheme.resolve(choice: nil, preferredLocalization: "it-IT") == .defaultTheme)
        #expect(BrandTheme.resolve(choice: nil, preferredLocalization: nil) == .defaultTheme)
        #expect(BrandTheme.resolve(choice: nil, preferredLocalization: "") == .defaultTheme)
    }
    
    // MARK: - Localized picker labels
    
    /// Serialises tests that mutate the process-wide localisation overrides: Swift Testing
    /// runs suites concurrently and the overrides are `nonisolated(unsafe)` globals shared
    /// with LocalizationTests and LanguageSettingsTests.
    private static let overridesLock = NSLock()
    
    private func withOverrideLocalizations(_ languages: [String], _ body: () -> Void) {
        Self.overridesLock.lock()
        defer { Self.overridesLock.unlock() }
        
        Bundle.overrideLocalizations = languages
        body()
        Bundle.overrideLocalizations = nil
    }
    
    /// The Automatic option and theme labels are translated in the Untranslated tables.
    @Test
    func localizedPickerLabels() {
        withOverrideLocalizations(["en"]) {
            #expect(BrandTheme.automaticOptionName == "Automatic (by language)")
            #expect(BrandTheme.defaultTheme.localizedName == "Default")
            #expect(BrandTheme.z.localizedName == "Z theme")
            #expect(BrandTheme.l.localizedName == "L theme")
        }
        
        withOverrideLocalizations(["vi"]) {
            #expect(BrandTheme.automaticOptionName == "Tự động (theo ngôn ngữ)")
            #expect(BrandTheme.z.localizedName == "Giao diện Z")
        }
        
        withOverrideLocalizations(["ja"]) {
            #expect(BrandTheme.automaticOptionName == "自動（言語に合わせる）")
            #expect(BrandTheme.l.localizedName == "Lテーマ")
        }
    }
    
    /// The friend-request display label is localized while the wire body stays English.
    @Test
    func friendRequestDisplayLabelPerLanguage() {
        withOverrideLocalizations(["en"]) {
            #expect(UntranslatedL10n.friendRequestDisplayBody == "👋 Friend request")
        }
        
        withOverrideLocalizations(["vi"]) {
            #expect(UntranslatedL10n.friendRequestDisplayBody == "👋 Lời mời kết bạn")
        }
        
        withOverrideLocalizations(["ja"]) {
            #expect(UntranslatedL10n.friendRequestDisplayBody == "👋 フレンド申請")
        }
        
        // The sent wire v2 shape is unchanged for interoperability: custom format + English body.
        #expect(FriendsService.markerFormat == "io.nagi.friend_request")
        #expect(FriendsService.markerBody == "👋 Friend request")
    }
    
    // MARK: - Read indicator labels (ADR 0016 knob table)
    
    @Test
    func readIndicatorLabelsPerLanguage() {
        withOverrideLocalizations(["en"]) {
            #expect(UntranslatedL10n.readIndicatorRead == "Read")
            #expect(UntranslatedL10n.readIndicatorReadFormat(3) == "Read 3")
        }
        
        withOverrideLocalizations(["vi"]) {
            #expect(UntranslatedL10n.readIndicatorRead == "Đã xem")
            #expect(UntranslatedL10n.readIndicatorReadFormat(3) == "Đã xem 3")
        }
        
        withOverrideLocalizations(["ja"]) {
            #expect(UntranslatedL10n.readIndicatorRead == "既読")
            #expect(UntranslatedL10n.readIndicatorReadFormat(3) == "既読 3")
        }
    }
}
