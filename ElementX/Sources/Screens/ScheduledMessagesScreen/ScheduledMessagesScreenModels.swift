//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

struct ScheduledMessagesScreenViewState: BindableState {
    var records = [ScheduledMessageRecord]()
    
    var bindings: ScheduledMessagesScreenViewStateBindings
    
    var hasContent: Bool {
        !records.isEmpty
    }
}

struct ScheduledMessagesScreenViewStateBindings {
    var alertInfo: AlertInfo<UUID>?
}

enum ScheduledMessagesScreenViewAction {
    case sendNow(delayId: String)
    case cancel(delayId: String)
}
