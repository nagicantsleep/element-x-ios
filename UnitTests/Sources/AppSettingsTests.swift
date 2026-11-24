//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

struct AppSettingsTests {
    @Test
    func defaultAccountProvider() {
        let appSettings = AppSettings.volatile()
        #expect(appSettings.defaultAccountProvider == appSettings.accountProviders[0])
        
        appSettings.previousServers = ["example.com"]
        #expect(appSettings.defaultAccountProvider == .generic("example.com"))
        
        appSettings.override(allowOtherAccountProviders: false)
        #expect(appSettings.defaultAccountProvider == appSettings.accountProviders[0])
    }
    
    // MARK: - Brand theme choice (ADR 0016)
    
    /// A fresh install has no stored choice: Automatic, resolving from the app language.
    @Test
    func brandThemeChoiceDefaultsToAutomatic() {
        let appSettings = AppSettings.volatile()
        #expect(appSettings.brandThemeChoice == nil)
    }
    
    /// The effective theme follows the explicit choice regardless of the machine's language.
    @Test
    func effectiveBrandThemeFollowsChoice() {
        let appSettings = AppSettings.volatile()
        
        appSettings.brandThemeChoice = .z
        #expect(appSettings.effectiveBrandTheme == .z)
        
        appSettings.brandThemeChoice = .l
        #expect(appSettings.effectiveBrandTheme == .l)
        
        appSettings.brandThemeChoice = .defaultTheme
        #expect(appSettings.effectiveBrandTheme == .defaultTheme)
        
        appSettings.brandThemeChoice = nil
        // Automatic: resolve against a pinned language so the assertion holds on any machine.
        Bundle.overridePreferredLocalizations = ["en"]
        defer { Bundle.overridePreferredLocalizations = nil }
        #expect(appSettings.effectiveBrandTheme == BrandTheme.resolve(choice: nil, preferredLocalization: "en"))
    }
    
    /// A legacy `brandTheme` value stored before ADR 0016 migrates into the optional choice.
    @Test
    func legacyBrandThemePreferenceMigrates() throws {
        let legacyData = try JSONEncoder().encode(BrandTheme.l)
        let appSettings = AppSettings(store: VolatileUserDefaults(initialValues: ["brandTheme": legacyData]))
        
        #expect(appSettings.brandThemeChoice == .l)
        #expect(appSettings.effectiveBrandTheme == .l)
    }
    
    /// A legacy value only migrates when the new preference hasn't been written yet.
    @Test
    func explicitChoiceWinsOverLegacyValue() throws {
        let legacyData = try JSONEncoder().encode(BrandTheme.z)
        let choiceData = try JSONEncoder().encode(BrandTheme.defaultTheme)
        let appSettings = AppSettings(store: VolatileUserDefaults(initialValues: ["brandTheme": legacyData,
                                                                                  "brandThemeChoice": choiceData]))
        
        #expect(appSettings.brandThemeChoice == .defaultTheme)
        #expect(appSettings.effectiveBrandTheme == .defaultTheme)
    }
}

// MARK: - Helpers

private extension AppSettings {
    func override(allowOtherAccountProviders: Bool) {
        override(accountProviders: accountProviders,
                 allowOtherAccountProviders: allowOtherAccountProviders,
                 hideBrandChrome: hideBrandChrome,
                 pushGatewayBaseURL: pushGatewayBaseURL,
                 oAuthRedirectURL: oAuthRedirectURL,
                 oAuthClientURIPath: oAuthClientURIPath,
                 websiteURL: websiteURL,
                 logoURL: logoURL,
                 copyrightURL: copyrightURL,
                 acceptableUseURL: acceptableUseURL,
                 privacyURL: privacyURL,
                 encryptionURL: encryptionURL,
                 deviceVerificationURL: deviceVerificationURL,
                 chatBackupDetailsURL: chatBackupDetailsURL,
                 identityPinningViolationDetailsURL: identityPinningViolationDetailsURL,
                 historySharingDetailsURL: historySharingDetailsURL,
                 elementWebHosts: elementWebHosts,
                 accountProvisioningHost: accountProvisioningHost,
                 bugReportApplicationID: bugReportApplicationID,
                 analyticsTermsURL: analyticsTermsURL,
                 mapTilerConfiguration: mapTilerConfiguration.publisher.value)
    }
}
