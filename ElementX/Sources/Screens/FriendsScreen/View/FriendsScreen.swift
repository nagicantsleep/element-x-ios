//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct FriendsScreen: View {
    @Bindable var context: FriendsScreenViewModel.Context
    
    var body: some View {
        Form {
            addFriendSection
            incomingRequestsSection
            outgoingRequestsSection
            friendsSection
        }
        .compoundList()
        .navigationTitle(UntranslatedL10n.screenFriendsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .alert(item: $context.alertInfo)
        .sheet(isPresented: $context.isMyQRDisplayed) {
            MyQRCodeView(userID: context.viewState.ownUserID,
                         url: context.viewState.myQRCodeURL)
                .presentationDetents([.medium])
        }
    }
    
    // MARK: - Private
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(UntranslatedL10n.screenFriendsMyQr) {
                context.send(viewAction: .displayMyQR)
            }
        }
    }
    
    private var addFriendSection: some View {
        Section {
            HStack {
                TextField(UntranslatedL10n.screenFriendsAddHint, text: $context.addFriendText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier(A11yIdentifiers.friendsScreen.addFriendField)
                
                Button(action: { context.send(viewAction: .addFriend) }) {
                    Image(systemName: "person.badge.plus")
                }
                .disabled(context.addFriendText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier(A11yIdentifiers.friendsScreen.addFriendButton)
            }
        } header: {
            Text(UntranslatedL10n.screenFriendsAddHeader)
        }
    }
    
    @ViewBuilder
    private var incomingRequestsSection: some View {
        if !context.viewState.incoming.isEmpty {
            Section {
                ForEach(context.viewState.incoming, id: \.userID) { request in
                    ListRow(label: .default(title: request.displayName ?? request.userID,
                                            icon: \.user),
                            kind: .button {
                                context.send(viewAction: .accept(userID: request.userID))
                            })
                            .accessibilityIdentifier(A11yIdentifiers.friendsScreen.accept)
                    
                    ListRow(label: .default(title: UntranslatedL10n.screenFriendsReject,
                                            icon: \.close,
                                            role: .destructive),
                            kind: .button {
                                context.send(viewAction: .reject(userID: request.userID))
                            })
                            .accessibilityIdentifier(A11yIdentifiers.friendsScreen.reject)
                }
            } header: {
                Text(UntranslatedL10n.screenFriendsIncomingHeader)
            }
        }
    }
    
    @ViewBuilder
    private var outgoingRequestsSection: some View {
        if !context.viewState.outgoing.isEmpty {
            Section {
                ForEach(context.viewState.outgoing, id: \.userID) { request in
                    ListRow(label: .default(title: request.userID,
                                            icon: \.user),
                            kind: .button {
                                context.send(viewAction: .cancel(userID: request.userID))
                            })
                            .accessibilityIdentifier(A11yIdentifiers.friendsScreen.cancel)
                }
            } header: {
                Text(UntranslatedL10n.screenFriendsOutgoingHeader)
            }
        }
    }
    
    @ViewBuilder
    private var friendsSection: some View {
        if !context.viewState.friends.isEmpty {
            Section {
                ForEach(context.viewState.friends, id: \.userID) { friend in
                    ListRow(label: .default(title: friend.displayName ?? friend.userID,
                                            icon: \.user),
                            kind: .label)
                }
            } header: {
                Text(UntranslatedL10n.screenFriendsListHeader)
            }
        }
    }
}

// MARK: - My QR

private struct MyQRCodeView: View {
    let userID: String
    let url: URL?
    
    var body: some View {
        VStack(spacing: 24) {
            if let image = qrImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .accessibilityLabel(L10n.a11yQrCode)
            }
            
            Text(userID)
                .font(.compound.bodyLG)
        }
        .padding()
        .navigationTitle(UntranslatedL10n.screenFriendsMyQr)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var qrImage: UIImage? {
        guard let url, let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        
        filter.setValue(url.absoluteString.data(using: .isoLatin1), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        filter.setValue(1, forKey: "inputQuietZone")
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let scale = 660 / outputImage.extent.width
        let scaled = outputImage.transformed(by: .init(scaleX: scale, y: scale))
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Previews

struct FriendsScreen_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        let viewModel = makeViewModel()
        FriendsScreen(context: viewModel.context)
    }
    
    static func makeViewModel() -> FriendsScreenViewModel {
        let service = FriendsServiceMock()
        service.friendsReturnValue = .success([FriendEntry(userID: "@bob:example.org", displayName: "Bob", addedAt: 1)])
        service.requestsReturnValue = .success((incoming: [FriendRequest(userID: "@carol:example.org",
                                                                         displayName: nil,
                                                                         direction: .incoming,
                                                                         createdAt: 1)],
                                                outgoing: [FriendRequest(userID: "@dave:example.org",
                                                                         displayName: nil,
                                                                         direction: .outgoing,
                                                                         createdAt: 1)]))
        return FriendsScreenViewModel(friendsService: service,
                                      userIndicatorController: UserIndicatorControllerMock(),
                                      ownUserID: "@alice:example.org")
    }
}
