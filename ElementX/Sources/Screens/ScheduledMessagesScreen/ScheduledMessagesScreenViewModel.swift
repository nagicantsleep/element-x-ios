//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias ScheduledMessagesScreenViewModelType = StateStoreViewModelV2<ScheduledMessagesScreenViewState, ScheduledMessagesScreenViewAction>

class ScheduledMessagesScreenViewModel: ScheduledMessagesScreenViewModelType, ScheduledMessagesScreenViewModelProtocol {
    private let schedulingService: any SchedulingServiceProtocol
    private let roomID: String
    
    private let actionsSubject: PassthroughSubject<ScheduledMessagesScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<ScheduledMessagesScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(schedulingService: any SchedulingServiceProtocol, roomID: String) {
        self.schedulingService = schedulingService
        self.roomID = roomID
        
        super.init(initialViewState: ScheduledMessagesScreenViewState(records: schedulingService.records(roomID: roomID),
                                                                      bindings: .init()))
    }
    
    // MARK: - Public
    
    func refresh() {
        state.records = schedulingService.records(roomID: roomID)
    }
    
    override func process(viewAction: ScheduledMessagesScreenViewAction) {
        switch viewAction {
        case .sendNow(let delayId):
            Task { await update(delayId: delayId) { try await self.schedulingService.sendNow(delayId: $0).get() } }
        case .cancel(let delayId):
            Task { await update(delayId: delayId) { try await self.schedulingService.cancel(delayId: $0).get() } }
        }
    }
    
    // MARK: - Private
    
    private func update(delayId: String, action: (String) async throws -> Void) async {
        do {
            try await action(delayId)
            state.records = schedulingService.records(roomID: roomID)
        } catch {
            MXLog.error("Failed updating the scheduled message \(delayId)")
            state.bindings.alertInfo = .init(id: UUID(), title: UntranslatedL10n.screenScheduledMessagesErrorFailed)
        }
    }
}
