//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum FriendsScreenViewModelAction {
    case dismiss
}

struct FriendsScreenViewState: BindableState {
    var friends = [FriendEntry]()
    var incoming = [FriendRequest]()
    var outgoing = [FriendRequest]()
    
    var bindings: FriendsScreenViewStateBindings
    
    var myQRCodeURL: URL? {
        FriendsService.matrixToURL(for: ownUserID)
    }
    
    let ownUserID: String
    
    var hasContent: Bool {
        !incoming.isEmpty || !outgoing.isEmpty || !friends.isEmpty
    }
}

struct FriendsScreenViewStateBindings {
    var addFriendText = ""
    var isMyQRDisplayed = false
    var alertInfo: AlertInfo<FriendsScreenAlertType>?
}

enum FriendsScreenAlertType: Hashable {
    case failedLoading
    case failedAddingFriend
    case failedAcceptingFriend
    case failedRemovingFriend
    case invalidUserID
}

enum FriendsScreenViewAction {
    case accept(userID: String)
    case reject(userID: String)
    case cancel(userID: String)
    case remove(userID: String)
    case addFriend
    case displayMyQR
    case hideMyQR
}
