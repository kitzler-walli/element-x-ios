//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine

protocol LinkAppleWatchScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<LinkAppleWatchScreenViewModelAction, Never> { get }
    var context: LinkAppleWatchScreenViewModelType.Context { get }

    /// Cancels any linking in progress, telling the watch to stop too.
    func stop()
}
