//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct WatchRoomScreen: View {
    @Bindable var context: WatchRoomScreenViewModel.Context

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if !context.viewState.isLoading, !context.viewState.messages.isEmpty {
                        Color.clear
                            .frame(height: 1)
                            .onAppear { context.send(viewAction: .loadOlderMessages) }
                    }

                    ForEach(context.viewState.messages) { message in
                        WatchMessageBubble(message: message)
                            .id(message.id)
                    }

                    replyButton
                        .id(Self.bottomID)
                }
            }
            .onChange(of: context.viewState.messages.last?.id) {
                withAnimation { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            }
            .onAppear {
                proxy.scrollTo(Self.bottomID, anchor: .bottom)
            }
        }
        .overlay {
            if context.viewState.isLoading {
                ProgressView()
            }
        }
        .navigationTitle(context.viewState.roomName)
        .alert(item: $context.alertInfo)
        .onAppear { context.send(viewAction: .appeared) }
    }

    private static let bottomID = "bottom"

    // Presents the system text input: dictation, Scribble or the keyboard on larger watches.
    private var replyButton: some View {
        TextFieldLink(prompt: Text(UntranslatedL10n.screenWatchRoomReplyPlaceholderIos)) {
            Label(L10n.actionReply, icon: \.reply)
                .frame(maxWidth: .infinity)
        } onSubmit: { message in
            context.send(viewAction: .send(message))
        }
        .disabled(context.viewState.isLoading || context.viewState.isSending)
        .padding(.top, 4)
    }
}

private struct WatchMessageBubble: View {
    let message: WatchTimelineMessage

    var body: some View {
        VStack(alignment: message.isOwn ? .trailing : .leading, spacing: 2) {
            if !message.isOwn {
                Text(message.senderName)
                    .font(.compound.bodyXSSemibold)
                    .foregroundStyle(.compound.textSecondary)
                    .lineLimit(1)
            }

            Text(message.body)
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(message.isOwn ? Color.compound.bgAccentSubtle : Color.compound.bgSubtleSecondary,
                            in: RoundedRectangle(cornerRadius: 12))

            switch message.sendState {
            case .sent:
                EmptyView()
            case .sending:
                Text(L10n.commonSending)
                    .font(.compound.bodyXS)
                    .foregroundStyle(.compound.textSecondary)
            case .failed:
                Text(L10n.commonSendingFailed)
                    .font(.compound.bodyXS)
                    .foregroundStyle(.compound.textCriticalPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isOwn ? .trailing : .leading)
    }
}
