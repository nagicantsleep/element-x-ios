//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

extension LanguageSetting {
    /// The row title: each language rendered in its own language so every option is
    /// recognisable regardless of the language the app currently displays.
    var pickerTitle: String {
        switch self {
        case .systemDefault: UntranslatedL10n.screenLanguagePickerSystemDefault
        case .english: "English"
        case .japanese: "日本語"
        case .vietnamese: "Tiếng Việt"
        }
    }
}

enum LanguagePickerScreenViewModelAction {
    /// The user picked a language; the app must be restarted for it to apply.
    case languageSelected
}

struct LanguagePickerScreenViewState: BindableState {
    /// The language the OS currently applies, shown with a checkmark.
    var selectedLanguage: LanguageSetting
    
    var bindings = LanguagePickerScreenViewStateBindings()
}

struct LanguagePickerScreenViewStateBindings {
    /// Alert announcing that the language change requires an app restart.
    var isShowingRestartAlert = false
}

enum LanguagePickerScreenViewAction {
    case select(LanguageSetting)
}
