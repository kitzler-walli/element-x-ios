//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum WatchOnboardingScreenViewModelAction {
    case signedIn(WatchUserSession)
}

struct WatchOnboardingScreenViewState: BindableState {
    enum Step: Equatable {
        case idle
        /// The phone was asked to start linking, waiting for its login code.
        case waitingForPhone
        case phoneUnreachable
        case connecting
        case waitingForApproval
        case verifying
        case failed

        var isLinking: Bool {
            switch self {
            case .connecting, .waitingForApproval, .verifying: true
            default: false
            }
        }
    }

    var step: Step = .idle
    /// The code to type on the phone when the account provider doesn't fill it in.
    var userCode: String?

    var message: String {
        switch step {
        case .idle: UntranslatedL10n.screenWatchOnboardingMessageIos
        case .waitingForPhone: UntranslatedL10n.screenWatchOnboardingWaitingIos
        case .phoneUnreachable: UntranslatedL10n.screenWatchOnboardingIphoneUnreachableIos
        case .connecting: UntranslatedL10n.screenWatchOnboardingConnectingIos
        case .waitingForApproval: UntranslatedL10n.screenWatchOnboardingApproveIos
        case .verifying: UntranslatedL10n.screenWatchOnboardingVerifyingIos
        case .failed: UntranslatedL10n.screenWatchOnboardingFailedIos
        }
    }
}

enum WatchOnboardingScreenViewAction {
    case requestSetUp
}
