//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct LanguagePickerScreen: View {
    @Bindable var context: LanguagePickerScreenViewModel.Context
    
    var body: some View {
        Form {
            optionsSection
        }
        .compoundList()
        .navigationTitle(UntranslatedL10n.screenLanguagePickerTitle)
        .navigationBarTitleDisplayMode(.inline)
        .restartAlert(binding: $context.isShowingRestartAlert)
    }
    
    private var optionsSection: some View {
        Section {
            ForEach(LanguageSetting.allCases, id: \.self) { setting in
                optionRow(for: setting)
            }
        }
    }
    
    private func optionRow(for setting: LanguageSetting) -> some View {
        ListRow(label: .plain(title: setting.pickerTitle),
                kind: .selection(isSelected: context.viewState.selectedLanguage == setting) {
                    context.send(viewAction: .select(setting))
                })
                .accessibilityIdentifier(A11yIdentifiers.languagePickerScreen.languageRow(setting))
    }
}

private extension View {
    /// Alert announcing that the language change requires an app restart.
    func restartAlert(binding: Binding<Bool>) -> some View {
        alert(UntranslatedL10n.screenLanguagePickerChangedTitle, isPresented: binding) {
            Button(UntranslatedL10n.screenLanguagePickerRestartNow) {
                // Destroying the scene sessions terminates the process so the saved
                // language applies on the automatic relaunch. A no-op where the OS
                // declines (e.g. macOS), in which case the user relaunches manually.
                if let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first {
                    UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
                }
            }
            Button(L10n.actionOk, role: .cancel) {
                // The dismissal itself is handled by the binding; nothing further to do.
            }
        } message: {
            Text(UntranslatedL10n.screenLanguagePickerChangedMessage)
        }
    }
}

struct LanguagePickerScreen_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        LanguagePickerScreen(context: LanguagePickerScreenViewModel().context)
    }
}
