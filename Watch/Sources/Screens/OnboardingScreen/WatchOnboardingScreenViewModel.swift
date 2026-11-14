//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias WatchOnboardingScreenViewModelType = StateStoreViewModelV2<WatchOnboardingScreenViewState, WatchOnboardingScreenViewAction>

/// Signs the watch in with the help of the phone, which provides the login code and verifies the new session.
final class WatchOnboardingScreenViewModel: WatchOnboardingScreenViewModelType {
    private let authenticationService: WatchAuthenticationService
    private let watchLinkService: WatchLinkServiceProtocol
    private var loginTask: Task<Void, Never>?
    /// Identifies the latest login attempt so that a superseded one can't update the state.
    private var loginAttemptID: UUID?

    private let actionsSubject: PassthroughSubject<WatchOnboardingScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<WatchOnboardingScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(authenticationService: WatchAuthenticationService, watchLinkService: WatchLinkServiceProtocol) {
        self.authenticationService = authenticationService
        self.watchLinkService = watchLinkService

        super.init(initialViewState: .init())

        watchLinkService.messagesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in self?.handle(message) }
            .store(in: &cancellables)
    }

    override func process(viewAction: WatchOnboardingScreenViewAction) {
        switch viewAction {
        case .requestSetUp:
            requestSetUp()
        }
    }

    // MARK: - Private

    private func requestSetUp() {
        guard !state.step.isLinking else { return }

        switch watchLinkService.send(.linkRequested) {
        case .success:
            state.step = .waitingForPhone
        case .failure(let error):
            MXLog.error("Failed asking the phone to link: \(error)")
            state.step = .phoneUnreachable
        }
    }

    private func handle(_ message: WatchLinkMessage) {
        switch message {
        case .loginCode(let data):
            login(with: data)
        case .cancelled:
            guard let loginTask else { return }
            MXLog.info("The phone cancelled the linking.")
            loginTask.cancel()
        case .linkRequested, .checkCode, .watchSignedIn:
            MXLog.error("Unexpected \(message) received from the phone.")
        }
    }

    private func login(with data: Data) {
        // A fresh code means the phone restarted the linking, so drop any attempt in flight.
        loginTask?.cancel()
        state.step = .connecting

        let attemptID = UUID()
        loginAttemptID = attemptID

        loginTask = Task { [weak self] in
            guard let self else { return }

            let result = await authenticationService.loginWithQRCode(data: data) { [weak self] progress in
                guard self?.loginAttemptID == attemptID else { return }
                self?.handle(progress)
            }

            guard loginAttemptID == attemptID else { return } // Superseded by a newer attempt.
            loginTask = nil
            loginAttemptID = nil

            guard !Task.isCancelled else {
                state.step = .failed
                return
            }

            switch result {
            case .success(let userSession):
                MXLog.info("Signed in and verified.")
                _ = watchLinkService.send(.watchSignedIn)
                actionsSubject.send(.signedIn(userSession))
            case .failure(let error):
                MXLog.error("Linking failed: \(error)")
                _ = watchLinkService.send(.cancelled)
                state.step = .failed
            }
        }
    }

    private func handle(_ progress: WatchLoginProgress) {
        switch progress {
        case .starting:
            state.step = .connecting
        case .establishingSecureChannel(let checkCode):
            if case .failure(let error) = watchLinkService.send(.checkCode(checkCode)) {
                MXLog.error("Failed returning the check code to the phone: \(error)")
                loginTask?.cancel()
            }
        case .waitingForApproval(let userCode):
            state.userCode = userCode
            state.step = .waitingForApproval
        case .syncingSecrets:
            state.step = .verifying
        }
    }
}
