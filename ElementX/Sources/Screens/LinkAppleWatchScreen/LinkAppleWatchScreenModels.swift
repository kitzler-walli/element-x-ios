//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum LinkAppleWatchScreenViewModelAction: CustomStringConvertible {
    case verifyWithAppLockPIN(CheckedContinuation<Bool, Never>)
    case requestOAuthAuthorisation(URL, OAuthAccountSettingsPresenter.Continuation)
    case dismiss

    var description: String {
        switch self {
        case .verifyWithAppLockPIN: "verifyWithAppLockPIN"
        case .requestOAuthAuthorisation: "requestOAuthAuthorisation"
        case .dismiss: "dismiss"
        }
    }
}

struct LinkAppleWatchScreenViewState: BindableState {
    nonisolated enum Mode: Equatable {
        /// Waiting for the user to start linking.
        case idle
        case verifyingDeviceOwner
        /// The login code was handed to the watch, waiting for it to join the secure channel.
        case connecting
        /// The user needs to approve the sign in with their account provider.
        case waitingForAuthorisation
        /// The phone is sending its secrets to verify the watch.
        case verifying
        case done
        case error(QRCodeLoginState.ErrorState)

        var isLinking: Bool {
            switch self {
            case .connecting, .waitingForAuthorisation, .verifying: true
            default: false
            }
        }
    }

    nonisolated enum WatchAvailability: Equatable {
        case checking
        case notPaired
        case appNotInstalled
        case appNotOpen
        case available
    }

    var mode: Mode = .idle
    var watchAvailability: WatchAvailability
    var bindings = LinkAppleWatchScreenViewStateBindings()

    var canStartLinking: Bool {
        mode == .idle && watchAvailability == .available
    }

    /// The hint shown when linking can't start yet, if any.
    var availabilityMessage: String? {
        switch watchAvailability {
        case .checking, .available: nil
        case .notPaired: UntranslatedL10n.screenLinkAppleWatchNotPairedIos
        case .appNotInstalled: UntranslatedL10n.screenLinkAppleWatchAppNotInstalledIos
        case .appNotOpen: UntranslatedL10n.screenLinkAppleWatchOpenAppIos
        }
    }
}

struct LinkAppleWatchScreenViewStateBindings {
    var alertInfo: AlertInfo<UUID>?
}

enum LinkAppleWatchScreenViewAction {
    case link
    case errorAction(QRCodeErrorView.Action)
    case dismiss
}

nonisolated extension LinkAppleWatchScreenViewState.WatchAvailability {
    init(state: WatchLinkState) {
        self = if !state.isActivated {
            .checking
        } else if !state.isPaired {
            .notPaired
        } else if !state.isWatchAppInstalled {
            .appNotInstalled
        } else if !state.isReachable {
            .appNotOpen
        } else {
            .available
        }
    }
}
