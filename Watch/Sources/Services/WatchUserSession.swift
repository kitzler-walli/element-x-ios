//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import MatrixRustSDK

/// The signed in account on the watch together with the services that keep it in sync.
final class WatchUserSession {
    let client: ClientProtocol
    let userID: String
    let sessionDirectories: SessionDirectories
    let roomListProvider: WatchRoomListProvider

    private let syncService: SyncService
    private let roomListService: RoomListService
    private var syncStateHandle: TaskHandle?

    private let syncStateSubject = CurrentValueSubject<SyncServiceState, Never>(.idle)
    var syncStatePublisher: CurrentValuePublisher<SyncServiceState, Never> {
        syncStateSubject.asCurrentValuePublisher()
    }

    init(client: ClientProtocol, sessionDirectories: SessionDirectories) async throws {
        self.client = client
        userID = try client.userId()
        self.sessionDirectories = sessionDirectories

        syncService = try await client.syncService()
            .withOfflineMode()
            .finish()
        roomListService = syncService.roomListService()

        roomListProvider = WatchRoomListProvider(roomListService: roomListService, ownUserID: userID)
        try await roomListProvider.start()

        syncStateHandle = syncService.state(listener: SDKListener.onMainActor { [weak self] state in
            MXLog.info("Sync state changed: \(state)")
            self?.syncStateSubject.send(state)
        })
    }

    func startSync() async {
        MXLog.info("Starting sync.")
        await syncService.start()
    }

    func stopSync() async {
        MXLog.info("Stopping sync.")
        await syncService.stop()
    }

    /// Opens the live timeline of the room with the given identifier.
    func makeTimelineProvider(roomID: String) async throws -> WatchTimelineProvider {
        let room = try roomListService.room(roomId: roomID)
        return try await WatchTimelineProvider(room: room, ownUserID: userID)
    }
}
