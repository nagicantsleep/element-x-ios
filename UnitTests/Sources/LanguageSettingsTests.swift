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

final class LanguageSettingsTests {
    /// Each test gets its own suite so the host app's standard defaults are never touched.
    private let suiteName: String
    private let defaults: UserDefaults
    
    /// The language the OS resolves on this machine — `AppleLanguages` is a global preference
    /// and suite reads fall back to the global value when the domain has no entry.
    private let resolvedLanguage: LanguageSetting
    
    init() {
        suiteName = "LanguageSettingsTests-\(UUID().uuidString)"
        UserDefaults(suiteName: suiteName)!.removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)!
        
        resolvedLanguage = LanguageSetting(identifier: Bundle.app.preferredLocalizations.first ?? "") ?? .systemDefault
    }
    
    deinit {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }
    
    private func makeVM() -> LanguagePickerScreenViewModel {
        LanguagePickerScreenViewModel(defaults: defaults, appDomainName: suiteName)
    }
    
    /// The suite domain only, as `set` writes it.
    private func storedLanguages() -> [String]? {
        defaults.persistentDomain(forName: suiteName)?[LanguageSettingsStore.appleLanguagesKey] as? [String]
    }
    
    /// A picked language that differs from the machine's resolved language, if any.
    private var differentLanguage: LanguageSetting? {
        [.english, .japanese, .vietnamese].first { $0 != resolvedLanguage }
    }
    
    // MARK: - Store
    
    /// Writing a language persists the choice under `AppleLanguages` in the suite domain.
    @Test
    func setPersistsAppleLanguages() {
        LanguageSettingsStore.set(.japanese, defaults: defaults)
        
        #expect(storedLanguages() == ["ja"])
        #expect(LanguageSettingsStore.current(defaults: defaults) == .japanese)
    }
    
    /// Regional identifiers (as the OS per-app language row writes them) still match.
    @Test
    func currentMatchesRegionalIdentifier() {
        defaults.set(["ja-JP"], forKey: LanguageSettingsStore.appleLanguagesKey)
        
        #expect(LanguageSettingsStore.current(defaults: defaults) == .japanese)
    }
    
    /// Selecting system default removes the `AppleLanguages` key so the OS resolves the language again.
    @Test
    func systemDefaultRemovesKey() {
        LanguageSettingsStore.set(.vietnamese, defaults: defaults)
        #expect(storedLanguages() == ["vi"])
        
        LanguageSettingsStore.set(.systemDefault, defaults: defaults)
        
        #expect(storedLanguages() == nil)
    }
    
    /// With nothing stored, the effective OS language is surfaced so the picker never lies.
    @Test
    func currentFallsBackToPreferredLocalization() {
        #expect(storedLanguages() == nil)
        
        #expect(LanguageSettingsStore.current(defaults: defaults) == resolvedLanguage)
    }
    
    /// Unknown / unsupported stored languages fall back to the effective OS language.
    @Test
    func currentIgnoresUnsupportedStoredLanguage() {
        defaults.set(["it"], forKey: LanguageSettingsStore.appleLanguagesKey)
        
        #expect(LanguageSettingsStore.current(defaults: defaults) == resolvedLanguage)
    }
    
    /// Picking a language the OS doesn't apply needs a restart.
    @Test
    func needsRestartWhenPickingDifferentLanguage() {
        guard let differentLanguage else {
            Issue.record("This test requires the host to resolve to one of the picker languages.")
            return
        }
        
        #expect(!LanguageSettingsStore.needsRestart(for: resolvedLanguage, defaults: defaults, appDomainName: suiteName))
        #expect(LanguageSettingsStore.needsRestart(for: differentLanguage, defaults: defaults, appDomainName: suiteName))
    }
    
    /// Picking system default needs a restart only when an in-app override is being dropped.
    @Test
    func needsRestartForSystemDefaultOnlyWhenOverrideStored() {
        #expect(!LanguageSettingsStore.needsRestart(for: .systemDefault, defaults: defaults, appDomainName: suiteName))
        
        LanguageSettingsStore.set(.japanese, defaults: defaults)
        
        #expect(LanguageSettingsStore.needsRestart(for: .systemDefault, defaults: defaults, appDomainName: suiteName))
    }
    
    /// Re-picking the language the OS already applies doesn't need a restart.
    @Test
    func noRestartNeededWhenChoiceAlreadyApplied() {
        guard resolvedLanguage != .systemDefault else {
            Issue.record("The host doesn't resolve to one of the picker's languages.")
            return
        }
        
        LanguageSettingsStore.set(resolvedLanguage, defaults: defaults)
        
        #expect(!LanguageSettingsStore.needsRestart(for: resolvedLanguage, defaults: defaults, appDomainName: suiteName))
    }
    
    /// The stored-override probe sees the app-domain entry and ignores the global fallback.
    @Test
    func storedOverrideDetectsOnlyDomainEntries() {
        #expect(LanguageSettingsStore.storedOverride(defaults: defaults, appDomainName: suiteName) == nil)
        
        LanguageSettingsStore.set(.japanese, defaults: defaults)
        
        #expect(LanguageSettingsStore.storedOverride(defaults: defaults, appDomainName: suiteName) == ["ja"])
    }
    
    /// The fork's three tables + system default are all offered, each titled in its own language.
    @Test
    func optionsRenderInTheirOwnLanguage() {
        // Resolution independent: these literals never go through L10n.
        #expect(LanguageSetting.english.pickerTitle == "English")
        #expect(LanguageSetting.japanese.pickerTitle == "日本語")
        #expect(LanguageSetting.vietnamese.pickerTitle == "Tiếng Việt")
        #expect(LanguageSetting.allCases.count == 4)
    }
    
    /// The picker titles resolve through the Untranslated tables in the selected language.
    @Test
    func pickerStringsResolveInSelectedLanguage() {
        Bundle.overrideLocalizations = ["vi"]
        #expect(UntranslatedL10n.screenLanguagePickerTitle == "Ngôn ngữ")
        #expect(UntranslatedL10n.screenLanguagePickerSystemDefault == "Mặc định hệ thống")
        
        Bundle.overrideLocalizations = ["ja"]
        #expect(UntranslatedL10n.screenLanguagePickerTitle == "言語")
        #expect(UntranslatedL10n.screenLanguagePickerSystemDefault == "システムデフォルト")
        
        Bundle.overrideLocalizations = nil
        #expect(UntranslatedL10n.screenLanguagePickerTitle == "Language")
        #expect(UntranslatedL10n.screenLanguagePickerSystemDefault == "System default")
    }
    
    // MARK: - View model
    
    /// Selecting a language round-trips through the store and raises the restart alert.
    @Test
    func selectingLanguagePersistsAndRequestsRestart() throws {
        guard let differentLanguage else {
            Issue.record("This test requires the host to resolve to one of the picker languages.")
            return
        }
        
        let viewModel = makeVM()
        #expect(viewModel.state.selectedLanguage == resolvedLanguage)
        
        var receivedLanguageSelected = false
        let cancellable = viewModel.actions.sink { action in
            if case .languageSelected = action {
                receivedLanguageSelected = true
            }
        }
        
        viewModel.process(viewAction: .select(differentLanguage))
        
        #expect(viewModel.state.selectedLanguage == differentLanguage)
        #expect(try storedLanguages() == [#require(differentLanguage.languageCode)])
        #expect(viewModel.state.bindings.isShowingRestartAlert)
        #expect(receivedLanguageSelected)
        cancellable.cancel()
    }
    
    /// Re-picking the language the OS already applies doesn't show a restart alert.
    @Test
    func selectingAppliedLanguageSkipsRestartAlert() {
        guard resolvedLanguage != .systemDefault else {
            Issue.record("The host resolves to a language outside the picker's set.")
            return
        }
        
        let viewModel = makeVM()
        #expect(viewModel.state.selectedLanguage == resolvedLanguage)
        
        viewModel.process(viewAction: .select(resolvedLanguage))
        
        #expect(viewModel.state.selectedLanguage == resolvedLanguage)
        #expect(!viewModel.state.bindings.isShowingRestartAlert)
    }
    
    /// System default clears the stored choice and drops the override (restart needed).
    @Test
    func selectingSystemDefaultClearsStore() {
        LanguageSettingsStore.set(.japanese, defaults: defaults)
        let viewModel = makeVM()
        #expect(viewModel.state.selectedLanguage == .japanese)
        
        viewModel.process(viewAction: .select(.systemDefault))
        
        #expect(storedLanguages() == nil)
        #expect(viewModel.state.selectedLanguage == .systemDefault)
        #expect(viewModel.state.bindings.isShowingRestartAlert)
    }
}
