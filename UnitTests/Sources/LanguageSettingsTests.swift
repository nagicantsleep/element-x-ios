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
    /// Serialises tests that mutate the process-wide localisation overrides: Swift Testing
    /// runs suites concurrently and the overrides are `nonisolated(unsafe)` globals shared
    /// with LocalizationTests.
    private nonisolated(unsafe) static let overridesLock = NSLock()
    
    /// Every test pins the effective OS language so the suite is hermetic: the machine the
    /// tests run on may resolve to any language. English is chosen because the Untranslated
    /// fallback assertions below depend on it.
    private static let pinnedLanguage: LanguageSetting = .english
    
    /// Refcount of live instances pinning the OS language; Swift Testing creates one instance
    /// per test, so the pin must outlive each instance while any of them is running. Guarded
    /// by ``overridesLock``.
    private nonisolated(unsafe) static var pinnedInstanceCount = 0
    
    /// Each test gets its own suite so the host app's standard defaults are never touched.
    private let suiteName: String
    private let defaults: UserDefaults
    
    /// The pinned effective language; the store resolves through the override, never the host.
    private let resolvedLanguage: LanguageSetting
    
    init() {
        suiteName = "LanguageSettingsTests-\(UUID().uuidString)"
        UserDefaults(suiteName: suiteName)!.removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)!
        
        Self.overridesLock.lock()
        Self.pinnedInstanceCount += 1
        Bundle.overridePreferredLocalizations = [Self.pinnedLanguage.languageCode ?? "en"]
        Self.overridesLock.unlock()
        resolvedLanguage = Self.pinnedLanguage
    }
    
    deinit {
        Self.overridesLock.lock()
        Self.pinnedInstanceCount -= 1
        if Self.pinnedInstanceCount == 0 {
            Bundle.overridePreferredLocalizations = nil
        }
        Self.overridesLock.unlock()
        
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }
    
    private func makeVM() -> LanguagePickerScreenViewModel {
        LanguagePickerScreenViewModel(defaults: defaults, appDomainName: suiteName)
    }
    
    /// The suite domain only, as `set` writes it.
    private func storedLanguages() -> [String]? {
        defaults.persistentDomain(forName: suiteName)?[LanguageSettingsStore.appleLanguagesKey] as? [String]
    }
    
    /// A picked language that differs from the pinned effective language, if any.
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
            Issue.record("This test requires a resolvable language different from the pinned one.")
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
            Issue.record("The pinned language doesn't resolve to one of the picker's languages.")
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
        // The localisation overrides are process-wide globals also mutated by LocalizationTests;
        // hold the same lock so concurrently running suites don't observe each other's state.
        Self.overridesLock.lock()
        defer { Self.overridesLock.unlock() }
        
        Bundle.overrideLocalizations = ["vi"]
        #expect(UntranslatedL10n.screenLanguagePickerTitle == "Ngôn ngữ")
        #expect(UntranslatedL10n.screenLanguagePickerSystemDefault == "Mặc định hệ thống")
        
        Bundle.overrideLocalizations = ["ja"]
        #expect(UntranslatedL10n.screenLanguagePickerTitle == "言語")
        #expect(UntranslatedL10n.screenLanguagePickerSystemDefault == "システムデフォルト")
        
        // With no Untranslated-table override the suite's pinned OS language (English) applies.
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
            Issue.record("The pinned language resolves outside the picker's set.")
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
