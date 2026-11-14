//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

struct WatchRoomScreenViewState: BindableState {
    let roomName: String
    var messages: [WatchTimelineMessage] = []
    var isLoading = true
    var isSending = false
    var bindings = WatchRoomScreenViewStateBindings()
}

struct WatchRoomScreenViewStateBindings {
    var alertInfo: AlertInfo<UUID>?
}

enum WatchRoomScreenViewAction: CustomStringConvertible {
    case appeared
    case send(String)
    case loadOlderMessages

    // The reply is user content, so only log the case name.
    var description: String {
        switch self {
        case .appeared: "appeared"
        case .send: "send"
        case .loadOlderMessages: "loadOlderMessages"
        }
    }
}
