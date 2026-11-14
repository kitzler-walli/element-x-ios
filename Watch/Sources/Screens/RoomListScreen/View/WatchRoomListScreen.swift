//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct WatchRoomListScreen: View {
    let context: WatchRoomListScreenViewModel.Context

    var body: some View {
        List {
            if context.viewState.isOffline {
                Label(L10n.commonOffline, icon: \.offline)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                    .listRowBackground(Color.clear)
            }

            ForEach(context.viewState.rooms) { room in
                Button {
                    context.send(viewAction: .selectRoom(room))
                } label: {
                    WatchRoomListRow(room: room)
                }
                .onAppear {
                    if room.id == context.viewState.rooms.last?.id {
                        context.send(viewAction: .reachedEnd)
                    }
                }
            }
        }
        .overlay {
            if !context.viewState.hasLoaded {
                ProgressView()
            } else if context.viewState.rooms.isEmpty {
                Text(L10n.screenRoomlistEmptyTitle)
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textSecondary)
            }
        }
        .navigationTitle(L10n.commonChats)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    context.send(viewAction: .openSettings)
                } label: {
                    CompoundIcon(\.settings)
                }
                .accessibilityLabel(L10n.commonSettings)
            }
        }
    }
}

private struct WatchRoomListRow: View {
    let room: WatchRoomSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(room.name)
                    .font(room.unreadCount > 0 ? .compound.bodyMDSemibold : .compound.bodyMD)
                    .foregroundStyle(.compound.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if room.unreadCount > 0 {
                    Text(room.unreadCount, format: .number)
                        .font(.compound.bodyXSSemibold)
                        .foregroundStyle(.compound.textOnSolidPrimary)
                        .padding(.horizontal, 6)
                        .background(room.hasMentions ? Color.compound.iconAccentPrimary : Color.compound.iconSecondary, in: Capsule())
                }
            }

            if let lastMessage = room.lastMessage {
                Text(lastMessage)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                    .lineLimit(2)
            }

            if let date = room.lastMessageDate {
                Text(date, format: .relative(presentation: .named))
                    .font(.compound.bodyXS)
                    .foregroundStyle(.compound.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}
