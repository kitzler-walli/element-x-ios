//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct WatchOnboardingScreen: View {
    let context: WatchOnboardingScreenViewModel.Context

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                CompoundIcon(\.devices, size: .medium, relativeTo: .compound.headingSM)
                    .foregroundStyle(.compound.iconAccentPrimary)

                Text(UntranslatedL10n.screenWatchOnboardingTitleIos)
                    .font(.compound.headingSMSemibold)
                    .foregroundStyle(.compound.textPrimary)

                Text(context.viewState.message)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                    .multilineTextAlignment(.center)

                if context.viewState.step == .waitingForApproval, let userCode = context.viewState.userCode {
                    Text(userCode)
                        .font(.compound.headingSMSemibold.monospaced())
                        .foregroundStyle(.compound.textPrimary)
                        .accessibilityLabel(userCode.map(String.init).joined(separator: " "))
                }
                
                if context.viewState.step.isLinking {
                    ProgressView()
                } else {
                    Button(UntranslatedL10n.screenWatchOnboardingRequestActionIos) {
                        context.send(viewAction: .requestSetUp)
                    }
                    .tint(.compound.bgAccentRest)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

