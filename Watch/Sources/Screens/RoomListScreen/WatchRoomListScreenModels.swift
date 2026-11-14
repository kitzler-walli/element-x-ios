//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum WatchRoomListScreenViewModelAction {
    case openRoom(WatchRoomSummary)
    case openSettings
}

struct WatchRoomListScreenViewState: BindableState {
    var rooms: [WatchRoomSummary] = []
    var isOffline = false
    var hasLoaded = false
}

enum WatchRoomListScreenViewAction {
    case selectRoom(WatchRoomSummary)
    case reachedEnd
    case openSettings
}
