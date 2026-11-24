//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// The ADR 0016 room list header for the Z and L themes, replacing the stock large-title
/// navigation bar.
///
/// - Z: solid accent bar under the status bar with the search field inside it (white 20 % pill,
///   white icon/placeholder) and white QR / "+" actions; no large title.
/// - L: plain canvas; bold title left; plain (not circular) action icons right; grey `#F5F6F7`
///   search pill below.
struct BrandHomeHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @ObservedObject var context: HomeScreenViewModel.Context
    let kind: BrandLayout.HomeHeaderKind
    let settingsButton: any View
    let onStartChat: () -> Void
    
    var body: some View {
        switch kind {
        case .stock:
            EmptyView()
        case .zBar:
            zBar
        case .lPlain:
            lPlain
        }
    }
    
    // MARK: - Z (Zalo-like)
    
    private var zBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AnyView(settingsButton)
                
                Spacer()
                
                Button {
                    context.send(viewAction: .startChat)
                } label: {
                    CompoundIcon(\.qrCode)
                        .foregroundColor(.white)
                }
                .accessibilityLabel(L10n.actionStartChat)
                
                Button(action: onStartChat) {
                    CompoundIcon(\.plus)
                        .foregroundColor(.white)
                }
                .accessibilityLabel(L10n.actionStartChat)
                .accessibilityIdentifier(A11yIdentifiers.homeScreen.startChat)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            // White 20% pill search field inside the accent bar.
            HStack(spacing: 8) {
                CompoundIcon(\.search, size: .small, relativeTo: .compound.bodyMD)
                    .foregroundColor(.white.opacity(0.9))
                
                TextField(L10n.actionSearch, text: $context.searchQuery)
                    .font(.compound.bodyMD)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier(A11yIdentifiers.homeScreen.searchField)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(barColor.ignoresSafeArea(edges: .top))
    }
    
    // MARK: - L (LINE-like)
    
    private var lPlain: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text(title)
                    .font(.compound.headingLGBold)
                    .foregroundColor(.compound.textPrimary)
                
                Spacer()
                
                // Plain (not circular) action icons.
                Button {
                    context.send(viewAction: .startChat)
                } label: {
                    CompoundIcon(\.qrCode)
                        .foregroundColor(.compound.textPrimary)
                }
                .accessibilityLabel(L10n.actionStartChat)
                
                Button(action: onStartChat) {
                    CompoundIcon(\.plus)
                        .foregroundColor(.compound.textPrimary)
                }
                .accessibilityLabel(L10n.actionStartChat)
                .accessibilityIdentifier(A11yIdentifiers.homeScreen.startChat)
                
                AnyView(settingsButton)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Grey search pill below the title row.
            HStack(spacing: 8) {
                CompoundIcon(\.search, size: .small, relativeTo: .compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)
                
                TextField(L10n.actionSearch, text: $context.searchQuery)
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier(A11yIdentifiers.homeScreen.searchField)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(Color.compound.bgCanvasDefault.ignoresSafeArea(edges: .top))
    }
    
    // MARK: - Shared
    
    private var title: String {
        if let selectedSpace = context.viewState.selectedSpaceFilter {
            selectedSpace.room.name
        } else {
            L10n.screenRoomlistMainSpaceTitle
        }
    }
    
    /// The Z accent bar: brand blue in light mode; dark keeps a dark surface, never a light slab.
    private var barColor: Color {
        colorScheme == .dark ? .compound.bgSubtlePrimary : Color(uiColor: BrandTheme.uiColor("#0068FF"))
    }
}
