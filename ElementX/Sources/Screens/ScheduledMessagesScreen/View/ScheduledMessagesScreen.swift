//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct ScheduledMessagesScreen: View {
    @Bindable var context: ScheduledMessagesScreenViewModel.Context
    
    var body: some View {
        List {
            if context.viewState.hasContent {
                recordsSections
            } else {
                emptyStateSection
            }
        }
        .compoundList()
        .navigationTitle(UntranslatedL10n.screenScheduledMessagesTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $context.alertInfo)
    }
    
    // MARK: - Private
    
    private var recordsSections: some View {
        ForEach(context.viewState.records) { record in
            Section {
                ListRow(label: .default(title: record.messageBody.isEmpty ? record.eventType : record.messageBody,
                                        description: Self.sendAtFormatter.string(from: Date(timeIntervalSince1970: record.sendAt / 1000)),
                                        icon: \.time),
                        kind: .label)
                    .accessibilityIdentifier(A11yIdentifiers.scheduledMessagesScreen.record)
                
                ListRow(label: .default(title: UntranslatedL10n.screenScheduledMessagesSendNow, icon: \.send),
                        kind: .button {
                            context.send(viewAction: .sendNow(delayId: record.delayId))
                        })
                        .accessibilityIdentifier(A11yIdentifiers.scheduledMessagesScreen.sendNow)
                
                ListRow(label: .default(title: UntranslatedL10n.screenScheduledMessagesCancel, icon: \.close, role: .destructive),
                        kind: .button {
                            context.send(viewAction: .cancel(delayId: record.delayId))
                        })
                        .accessibilityIdentifier(A11yIdentifiers.scheduledMessagesScreen.cancel)
            }
        }
    }
    
    private var emptyStateSection: some View {
        Section {
            Text(UntranslatedL10n.screenScheduledMessagesEmptyState)
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
        }
    }
    
    private static let sendAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Previews

struct ScheduledMessagesScreen_Previews: PreviewProvider {
    static let viewModel = makeViewModel(records: [.init(delayId: "1",
                                                         roomId: "!room:example.com",
                                                         sendAt: Date().timeIntervalSince1970 * 1000 + 3_600_000,
                                                         content: ["body": "Hello world"],
                                                         eventType: "m.room.message")])
    static let emptyViewModel = makeViewModel(records: [])
    
    static var previews: some View {
        ScheduledMessagesScreen(context: viewModel.context)
        ScheduledMessagesScreen(context: emptyViewModel.context)
    }
    
    static func makeViewModel(records: [ScheduledMessageRecord]) -> ScheduledMessagesScreenViewModel {
        let mock = SchedulingServiceMock()
        mock.recordsRoomIDReturnValue = records
        return ScheduledMessagesScreenViewModel(schedulingService: mock, roomID: "!room:example.com")
    }
}
