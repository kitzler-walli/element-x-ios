//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

extension Bundle {
    /// The bundle holding the vendored token assets, which is the watch app itself rather than a package bundle.
    static var module: Bundle {
        .main
    }
}
