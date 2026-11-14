//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct WatchSettingsScreen: View {
    @Bindable var context: WatchSettingsScreenViewModel.Context

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.viewState.userID)
                        .font(.compound.bodyMDSemibold)
                        .foregroundStyle(.compound.textPrimary)

                    if let deviceID = context.viewState.deviceID {
                        Text(deviceID)
                            .font(.compound.bodyXS)
                            .foregroundStyle(.compound.textSecondary)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    context.send(viewAction: .logout)
                } label: {
                    Label(L10n.actionSignout, icon: \.signOut)
                }
            }
        }
        .navigationTitle(L10n.commonSettings)
        .confirmationDialog(L10n.actionSignout,
                            isPresented: $context.isPresentingLogoutConfirmation) {
            Button(L10n.actionSignout, role: .destructive) {
                context.send(viewAction: .confirmLogout)
            }
        } message: {
            Text(UntranslatedL10n.screenWatchSettingsSignOutMessageIos)
        }
    }
}
