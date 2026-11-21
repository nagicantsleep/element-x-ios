//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct FriendsScreenCoordinatorParameters {
    let friendsService: FriendsServiceProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
    let ownUserID: String
}

enum FriendsScreenCoordinatorAction {
    case dismiss
}

final class FriendsScreenCoordinator: CoordinatorProtocol {
    private var viewModel: FriendsScreenViewModelProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<FriendsScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<FriendsScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: FriendsScreenCoordinatorParameters) {
        viewModel = FriendsScreenViewModel(friendsService: parameters.friendsService,
                                           userIndicatorController: parameters.userIndicatorController,
                                           ownUserID: parameters.ownUserID)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            guard let self else { return }
            
            switch action {
            case .dismiss:
                actionsSubject.send(.dismiss)
            }
        }
        .store(in: &cancellables)
    }
    
    func stop() {
        viewModel.stop()
    }
    
    func toPresentable() -> AnyView {
        AnyView(FriendsScreen(context: viewModel.context))
    }
}
