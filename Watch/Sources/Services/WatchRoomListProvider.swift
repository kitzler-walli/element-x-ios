//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import MatrixRustSDK

/// A room as shown in the watch's room list.
struct WatchRoomSummary: Identifiable, Equatable {
    let id: String
    let name: String
    let lastMessage: String?
    let lastMessageDate: Date?
    let unreadCount: UInt
    let hasMentions: Bool
    let isInvite: Bool
}

/// Keeps a short, recency ordered list of the user's rooms up to date.
final class WatchRoomListProvider {
    // The watch shows a handful of rooms, larger pages only cost memory.
    private static let pageSize: UInt32 = 20

    private let roomListService: RoomListService
    private let ownUserID: String

    private var roomList: RoomList?
    private var entriesResult: RoomListEntriesWithDynamicAdaptersResult?
    private var rooms: [Room] = []
    private var summariesTask: Task<Void, Never>?

    private let summariesSubject = CurrentValueSubject<[WatchRoomSummary], Never>([])
    var summariesPublisher: CurrentValuePublisher<[WatchRoomSummary], Never> {
        summariesSubject.asCurrentValuePublisher()
    }

    init(roomListService: RoomListService, ownUserID: String) {
        self.roomListService = roomListService
        self.ownUserID = ownUserID
    }

    func start() async throws {
        let roomList = try await roomListService.allRooms()
        self.roomList = roomList

        let entriesResult = roomList.entriesWithDynamicAdapters(pageSize: Self.pageSize,
                                                                listener: SDKListener.onMainActor { [weak self] updates in
                                                                    self?.apply(updates)
                                                                })
        self.entriesResult = entriesResult

        // Setting the filter also delivers the current entries to the listener.
        _ = entriesResult.controller().setFilter(kind: .all(filters: [.nonSpace, .nonLeft, .deduplicateVersions]))
    }

    func loadMore() {
        entriesResult?.controller().addOnePage()
    }

    // MARK: - Private

    private func apply(_ updates: [RoomListEntriesUpdate]) {
        for update in updates {
            switch update {
            case .append(let values):
                rooms.append(contentsOf: values)
            case .clear:
                rooms.removeAll()
            case .pushFront(let value):
                rooms.insert(value, at: 0)
            case .pushBack(let value):
                rooms.append(value)
            case .popFront:
                if !rooms.isEmpty { rooms.removeFirst() }
            case .popBack:
                if !rooms.isEmpty { rooms.removeLast() }
            case .insert(let index, let value):
                rooms.insert(value, at: min(Int(index), rooms.count))
            case .set(let index, let value):
                if Int(index) < rooms.count { rooms[Int(index)] = value }
            case .remove(let index):
                if Int(index) < rooms.count { rooms.remove(at: Int(index)) }
            case .truncate(let length):
                rooms.removeSubrange(min(Int(length), rooms.count)...)
            case .reset(let values):
                rooms = values
            }
        }

        rebuildSummaries()
    }

    private func rebuildSummaries() {
        summariesTask?.cancel()

        let rooms = rooms
        let ownUserID = ownUserID
        summariesTask = Task { [weak self] in
            var summaries = [WatchRoomSummary]()
            summaries.reserveCapacity(rooms.count)

            for room in rooms {
                guard let summary = await WatchRoomSummary(room: room, ownUserID: ownUserID) else { continue }
                summaries.append(summary)
            }

            guard !Task.isCancelled else { return }
            self?.summariesSubject.send(summaries)
        }
    }
}

private extension WatchRoomSummary {
    init?(room: Room, ownUserID: String) async {
        guard let info = try? await room.roomInfo() else { return nil }

        id = info.id
        name = info.displayName ?? info.rawName ?? info.id
        unreadCount = UInt(info.numUnreadNotifications)
        hasMentions = info.numUnreadMentions > 0
        isInvite = info.membership == .invited

        switch await room.latestEvent() {
        case .remote(let timestamp, let sender, let isOwn, let profile, let content):
            lastMessage = content.watchSummary.map { info.isDirect ? $0 : "\(isOwn ? L10n.commonYou : profile.displayName(fallback: sender)): \($0)" }
            lastMessageDate = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        case .local(let timestamp, _, _, let content, _):
            lastMessage = content.watchSummary.map { info.isDirect ? $0 : "\(L10n.commonYou): \($0)" }
            lastMessageDate = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        case .remoteInvite(let timestamp, _, _):
            lastMessage = nil
            lastMessageDate = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        case .none:
            lastMessage = nil
            lastMessageDate = nil
        }
    }
}

extension ProfileDetails {
    /// The display name from the profile if it is loaded, otherwise the given fallback (usually the user ID).
    func displayName(fallback: String) -> String {
        if case .ready(let displayName, _, _, _, _) = self, let displayName, !displayName.isEmpty {
            return displayName
        }
        return fallback
    }
}

extension TimelineItemContent {
    /// A short, plain text description of the content for the watch, or `nil` for content that isn't shown.
    var watchSummary: String? {
        guard case .msgLike(let content) = self else { return nil }

        switch content.kind {
        case .message(let message):
            switch message.msgType {
            case .text, .emote, .notice, .other:
                return message.body
            case .image:
                return L10n.commonImage
            case .video:
                return L10n.commonVideo
            case .audio(let audio):
                return audio.voice != nil ? L10n.commonVoiceMessage : L10n.commonAudio
            case .file:
                return L10n.commonFile
            case .gallery:
                return L10n.commonImage
            case .location:
                return L10n.commonSharedLocation
            }
        case .sticker:
            return L10n.commonSticker
        case .poll(let question, _, _, _, _, _, _):
            return L10n.commonPollSummary(question)
        case .redacted:
            return L10n.commonMessageRemoved
        case .unableToDecrypt:
            return L10n.commonWaitingForDecryptionKey
        case .liveLocation:
            return L10n.commonSharedLocation
        case .other:
            return nil
        }
    }
}
