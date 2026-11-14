//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias WatchRoomScreenViewModelType = StateStoreViewModelV2<WatchRoomScreenViewState, WatchRoomScreenViewAction>

final class WatchRoomScreenViewModel: WatchRoomScreenViewModelType {
    private let roomID: String
    private let userSession: WatchUserSession
    private var timelineProvider: WatchTimelineProvider?

    init(room: WatchRoomSummary, userSession: WatchUserSession) {
        roomID = room.id
        self.userSession = userSession

        super.init(initialViewState: .init(roomName: room.name))
    }

    override func process(viewAction: WatchRoomScreenViewAction) {
        MXLog.info("View model: received view action: \(viewAction)")

        switch viewAction {
        case .appeared:
            Task { await loadTimelineIfNeeded() }
        case .send(let message):
            Task { await send(message) }
        case .loadOlderMessages:
            Task { await timelineProvider?.paginateBackwards() }
        }
    }

    // MARK: - Private

    private func loadTimelineIfNeeded() async {
        if let timelineProvider {
            await timelineProvider.markAsRead()
            return
        }

        do {
            let timelineProvider = try await userSession.makeTimelineProvider(roomID: roomID)
            self.timelineProvider = timelineProvider

            timelineProvider.messagesPublisher
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.state.messages, on: self)
                .store(in: &cancellables)

            await timelineProvider.paginateBackwards()
            state.isLoading = false
            await timelineProvider.markAsRead()
        } catch {
            MXLog.error("Failed loading the timeline for \(roomID): \(error)")
            state.isLoading = false
            state.bindings.alertInfo = AlertInfo(id: UUID(), title: L10n.errorUnknown)
        }
    }

    private func send(_ message: String) async {
        let message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, let timelineProvider else { return }

        state.isSending = true
        defer { state.isSending = false }

        if case .failure = await timelineProvider.send(message: message) {
            state.bindings.alertInfo = AlertInfo(id: UUID(), title: L10n.commonSendingFailed)
        }
    }
}
