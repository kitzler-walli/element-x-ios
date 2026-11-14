//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias WatchRoomListScreenViewModelType = StateStoreViewModelV2<WatchRoomListScreenViewState, WatchRoomListScreenViewAction>

final class WatchRoomListScreenViewModel: WatchRoomListScreenViewModelType {
    private let userSession: WatchUserSession

    private let actionsSubject: PassthroughSubject<WatchRoomListScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<WatchRoomListScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(userSession: WatchUserSession) {
        self.userSession = userSession

        super.init(initialViewState: .init())

        userSession.roomListProvider.summariesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rooms in
                self?.state.rooms = rooms
                self?.state.hasLoaded = true
            }
            .store(in: &cancellables)

        userSession.syncStatePublisher
            .map { $0 == .offline }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.isOffline, on: self)
            .store(in: &cancellables)
    }

    override func process(viewAction: WatchRoomListScreenViewAction) {
        switch viewAction {
        case .selectRoom(let room):
            actionsSubject.send(.openRoom(room))
        case .reachedEnd:
            userSession.roomListProvider.loadMore()
        case .openSettings:
            actionsSubject.send(.openSettings)
        }
    }
}
