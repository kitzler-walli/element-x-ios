//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

enum LinkAppleWatchScreenCoordinatorAction: CustomStringConvertible {
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

struct LinkAppleWatchScreenCoordinatorParameters {
    let clientProxy: ClientProxyProtocol
    let appLockService: AppLockServiceProtocol
    let watchLinkService: WatchLinkServiceProtocol
}

final class LinkAppleWatchScreenCoordinator: CoordinatorProtocol {
    private let viewModel: LinkAppleWatchScreenViewModelProtocol

    private var cancellables = Set<AnyCancellable>()

    private let actionsSubject: PassthroughSubject<LinkAppleWatchScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<LinkAppleWatchScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(parameters: LinkAppleWatchScreenCoordinatorParameters) {
        viewModel = LinkAppleWatchScreenViewModel(clientProxy: parameters.clientProxy,
                                                  appLockService: parameters.appLockService,
                                                  watchLinkService: parameters.watchLinkService)
    }

    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            MXLog.info("Coordinator: received view model action: \(action)")

            guard let self else { return }
            switch action {
            case .verifyWithAppLockPIN(let continuation):
                actionsSubject.send(.verifyWithAppLockPIN(continuation))
            case .requestOAuthAuthorisation(let url, let continuation):
                actionsSubject.send(.requestOAuthAuthorisation(url, continuation))
            case .dismiss:
                actionsSubject.send(.dismiss)
            }
        }
        .store(in: &cancellables)
    }

    func stop() {
        viewModel.stop()
    }

    func toPresentable() -> AnyView {
        AnyView(LinkAppleWatchScreen(context: viewModel.context))
    }
}
