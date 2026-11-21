//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias LanguagePickerScreenViewModelType = StateStoreViewModelV2<LanguagePickerScreenViewState, LanguagePickerScreenViewAction>

class LanguagePickerScreenViewModel: LanguagePickerScreenViewModelType, LanguagePickerScreenViewModelProtocol {
    private let defaults: UserDefaults
    private let appDomainName: String?
    
    private let actionsSubject: PassthroughSubject<LanguagePickerScreenViewModelAction, Never> = .init()
    
    var actions: AnyPublisher<LanguagePickerScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(defaults: UserDefaults = .standard, appDomainName: String? = nil) {
        self.defaults = defaults
        self.appDomainName = appDomainName
        
        super.init(initialViewState: LanguagePickerScreenViewState(selectedLanguage: LanguageSettingsStore.current(defaults: defaults)))
    }
    
    override func process(viewAction: LanguagePickerScreenViewAction) {
        switch viewAction {
        case .select(let setting):
            state.bindings.isShowingRestartAlert = LanguageSettingsStore.needsRestart(for: setting, defaults: defaults, appDomainName: appDomainName)
            LanguageSettingsStore.set(setting, defaults: defaults)
            state.selectedLanguage = setting
            
            if state.bindings.isShowingRestartAlert {
                actionsSubject.send(.languageSelected)
            }
        }
    }
}
