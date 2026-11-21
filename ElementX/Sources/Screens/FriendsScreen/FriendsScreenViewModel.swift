//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias FriendsScreenViewModelType = StateStoreViewModelV2<FriendsScreenViewState, FriendsScreenViewAction>

class FriendsScreenViewModel: FriendsScreenViewModelType, FriendsScreenViewModelProtocol {
    private let friendsService: any FriendsServiceProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private var actionsSubject: PassthroughSubject<FriendsScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<FriendsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(friendsService: any FriendsServiceProtocol,
         userIndicatorController: UserIndicatorControllerProtocol,
         ownUserID: String) {
        self.friendsService = friendsService
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: FriendsScreenViewState(bindings: .init(), ownUserID: ownUserID))
        
        Task { await loadContent() }
    }
    
    // MARK: - Public
    
    func stop() {
        hideLoadingIndicator()
    }
    
    override func process(viewAction: FriendsScreenViewAction) {
        switch viewAction {
        case .accept(let userID):
            Task { await accept(userID: userID) }
        case .reject(let userID), .cancel(let userID), .remove(let userID):
            Task { await removeFriendOrRequest(userID: userID) }
        case .addFriend:
            Task { await addFriend() }
        case .displayMyQR:
            state.bindings.isMyQRDisplayed = true
        case .hideMyQR:
            state.bindings.isMyQRDisplayed = false
        }
    }
    
    // MARK: - Private
    
    private func loadContent() async {
        showLoadingIndicator()
        
        switch await friendsService.friends() {
        case .success(let friends):
            state.friends = friends
        case .failure:
            state.bindings.alertInfo = .init(id: .failedLoading)
        }
        
        switch await friendsService.requests() {
        case .success(let requests):
            state.incoming = requests.incoming
            state.outgoing = requests.outgoing
        case .failure:
            state.bindings.alertInfo = .init(id: .failedLoading)
        }
        
        hideLoadingIndicator()
    }
    
    private func accept(userID: String) async {
        showLoadingIndicator()
        defer { hideLoadingIndicator() }
        
        switch await friendsService.accept(userID: userID) {
        case .success:
            state.incoming.removeAll { $0.userID == userID }
            if let friend = state.friends.first(where: { $0.userID == userID }) {
                _ = friend // Already in the list, nothing else to update.
            } else {
                state.friends.append(FriendEntry(userID: userID, displayName: nil, addedAt: Date().timeIntervalSince1970 * 1000))
            }
        case .failure:
            state.bindings.alertInfo = .init(id: .failedAcceptingFriend)
        }
    }
    
    private func removeFriendOrRequest(userID: String) async {
        showLoadingIndicator()
        defer { hideLoadingIndicator() }
        
        switch await friendsService.remove(userID: userID) {
        case .success:
            state.friends.removeAll { $0.userID == userID }
            state.incoming.removeAll { $0.userID == userID }
            state.outgoing.removeAll { $0.userID == userID }
        case .failure:
            state.bindings.alertInfo = .init(id: .failedRemovingFriend)
        }
    }
    
    private func addFriend() async {
        let userID = state.bindings.addFriendText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard FriendsService.isValidUserID(userID) else {
            state.bindings.alertInfo = .init(id: .invalidUserID)
            return
        }
        
        showLoadingIndicator()
        defer { hideLoadingIndicator() }
        
        switch await friendsService.sendRequest(userID: userID, displayName: nil) {
        case .success(let outcome):
            state.bindings.addFriendText = ""
            switch outcome {
            case .accepted:
                if !state.friends.contains(where: { $0.userID == userID }) {
                    state.friends.append(FriendEntry(userID: userID, displayName: nil, addedAt: Date().timeIntervalSince1970 * 1000))
                }
                state.incoming.removeAll { $0.userID == userID }
            case .requested:
                if !state.outgoing.contains(where: { $0.userID == userID }) {
                    state.outgoing.append(FriendRequest(userID: userID,
                                                        displayName: nil,
                                                        direction: .outgoing,
                                                        createdAt: Date().timeIntervalSince1970 * 1000))
                }
            case .alreadyFriends:
                if !state.friends.contains(where: { $0.userID == userID }) {
                    state.friends.append(FriendEntry(userID: userID, displayName: nil, addedAt: Date().timeIntervalSince1970 * 1000))
                }
            }
        case .failure:
            state.bindings.alertInfo = .init(id: .failedAddingFriend)
        }
    }
    
    // MARK: User Indicators
    
    private var loadingIndicatorIdentifier: String {
        "\(Self.self)-Loading"
    }
    
    private func showLoadingIndicator() {
        userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorIdentifier,
                                                              type: .modal(progress: .indeterminate, interactiveDismissDisabled: false, allowsInteraction: true),
                                                              title: L10n.commonLoading,
                                                              persistent: true),
                                                delay: .milliseconds(100))
    }
    
    private func hideLoadingIndicator() {
        userIndicatorController.retractIndicatorWithId(loadingIndicatorIdentifier)
    }
}
