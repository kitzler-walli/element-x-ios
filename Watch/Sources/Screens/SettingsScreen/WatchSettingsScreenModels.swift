//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum WatchSettingsScreenViewModelAction {
    case logout
}

struct WatchSettingsScreenViewState: BindableState {
    let userID: String
    let deviceID: String?
    var bindings = WatchSettingsScreenViewStateBindings()
}

struct WatchSettingsScreenViewStateBindings {
    var isPresentingLogoutConfirmation = false
}

enum WatchSettingsScreenViewAction {
    case logout
    case confirmLogout
}
