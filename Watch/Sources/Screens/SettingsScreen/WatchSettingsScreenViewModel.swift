//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias WatchSettingsScreenViewModelType = StateStoreViewModelV2<WatchSettingsScreenViewState, WatchSettingsScreenViewAction>

final class WatchSettingsScreenViewModel: WatchSettingsScreenViewModelType {
    private let actionsSubject: PassthroughSubject<WatchSettingsScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<WatchSettingsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(userSession: WatchUserSession) {
        super.init(initialViewState: .init(userID: userSession.userID,
                                           deviceID: try? userSession.client.deviceId()))
    }

    override func process(viewAction: WatchSettingsScreenViewAction) {
        switch viewAction {
        case .logout:
            state.bindings.isPresentingLogoutConfirmation = true
        case .confirmLogout:
            actionsSubject.send(.logout)
        }
    }
}
