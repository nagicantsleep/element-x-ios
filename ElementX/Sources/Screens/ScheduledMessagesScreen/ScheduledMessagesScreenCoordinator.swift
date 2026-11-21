//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct ScheduledMessagesScreenViewModelAction {
    // The screen manages its own list; no coordinator actions are needed yet.
}

struct ScheduledMessagesScreenCoordinatorParameters {
    let schedulingService: SchedulingServiceProtocol
    let roomID: String
}

final class ScheduledMessagesScreenCoordinator: CoordinatorProtocol {
    private let viewModel: ScheduledMessagesScreenViewModel
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<ScheduledMessagesScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<ScheduledMessagesScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: ScheduledMessagesScreenCoordinatorParameters) {
        viewModel = ScheduledMessagesScreenViewModel(schedulingService: parameters.schedulingService,
                                                     roomID: parameters.roomID)
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            self?.actionsSubject.send(action)
        }
        .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(ScheduledMessagesScreen(context: viewModel.context))
    }
}
