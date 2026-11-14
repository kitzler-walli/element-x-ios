//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import MatrixRustSDK

/// A message as shown in a watch conversation.
struct WatchTimelineMessage: Identifiable, Equatable {
    enum SendState: Equatable {
        case sending
        case sent
        case failed
    }

    let id: String
    let senderName: String
    let isOwn: Bool
    let body: String
    let date: Date
    let sendState: SendState
}

enum WatchTimelineProviderError: Error {
    case sendFailed
}

/// Observes the live timeline of a single room and sends replies to it.
final class WatchTimelineProvider {
    // Enough to give some context without holding lots of events in memory.
    private static let paginationSize: UInt16 = 20

    private let timeline: Timeline
    private let ownUserID: String
    private var items: [TimelineItem] = []
    private var listenerHandle: TaskHandle?

    private let messagesSubject = CurrentValueSubject<[WatchTimelineMessage], Never>([])
    var messagesPublisher: CurrentValuePublisher<[WatchTimelineMessage], Never> {
        messagesSubject.asCurrentValuePublisher()
    }

    init(room: Room, ownUserID: String) async throws {
        self.ownUserID = ownUserID
        timeline = try await room.timelineWithConfiguration(configuration: .init(focus: .live(hideThreadedEvents: true),
                                                                                 filter: .onlyMessage(types: [.text, .emote, .notice, .image, .video,
                                                                                                              .audio, .file, .location, .gallery]),
                                                                                 internalIdPrefix: nil,
                                                                                 dateDividerMode: .daily,
                                                                                 trackReadReceipts: .messageLikeEvents,
                                                                                 reportUtds: false))

        listenerHandle = await timeline.addListener(listener: SDKListener.onMainActor { [weak self] diffs in
            self?.apply(diffs)
        })
    }

    deinit {
        listenerHandle?.cancel()
    }

    func paginateBackwards() async {
        do {
            _ = try await timeline.paginateBackwards(numEvents: Self.paginationSize)
        } catch {
            MXLog.error("Failed paginating backwards: \(error)")
        }
    }

    func markAsRead() async {
        do {
            try await timeline.markAsRead(receiptType: .read)
        } catch {
            MXLog.error("Failed marking the room as read: \(error)")
        }
    }

    func send(message: String) async -> Result<Void, WatchTimelineProviderError> {
        do {
            _ = try await timeline.send(msg: messageEventContentFromMarkdown(md: message))
            return .success(())
        } catch {
            MXLog.error("Failed sending a message: \(error)")
            return .failure(.sendFailed)
        }
    }

    // MARK: - Private

    private func apply(_ diffs: [TimelineDiff]) {
        for diff in diffs {
            switch diff {
            case .append(let values):
                items.append(contentsOf: values)
            case .clear:
                items.removeAll()
            case .pushFront(let value):
                items.insert(value, at: 0)
            case .pushBack(let value):
                items.append(value)
            case .popFront:
                if !items.isEmpty { items.removeFirst() }
            case .popBack:
                if !items.isEmpty { items.removeLast() }
            case .insert(let index, let value):
                items.insert(value, at: min(Int(index), items.count))
            case .set(let index, let value):
                if Int(index) < items.count { items[Int(index)] = value }
            case .remove(let index):
                if Int(index) < items.count { items.remove(at: Int(index)) }
            case .truncate(let length):
                items.removeSubrange(min(Int(length), items.count)...)
            case .reset(let values):
                items = values
            }
        }

        messagesSubject.send(items.compactMap { item in
            item.asEvent().flatMap { WatchTimelineMessage(event: $0, id: item.uniqueId().id) }
        })
    }
}

private extension WatchTimelineMessage {
    init?(event: EventTimelineItem, id: String) {
        guard let body = event.content.watchSummary else { return nil }

        self.id = id
        senderName = event.senderProfile.displayName(fallback: event.sender)
        isOwn = event.isOwn
        self.body = body
        date = Date(timeIntervalSince1970: TimeInterval(event.timestamp) / 1000)

        sendState = switch event.localSendState {
        case .none, .sent: .sent
        case .notSentYet: .sending
        case .sendingFailed: .failed
        }
    }
}
