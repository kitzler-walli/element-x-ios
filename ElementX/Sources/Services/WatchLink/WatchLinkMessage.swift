//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// A message exchanged between the iPhone app and the watch app while linking the watch to the user's account.
///
/// The phone acts as the existing device of an MSC4108 login: it generates the QR code data and hands it straight
/// to the watch instead of displaying it, and the watch returns the check code instead of the user typing it.
nonisolated enum WatchLinkMessage: Codable, Equatable, Sendable {
    /// The watch asks the phone to start linking it.
    case linkRequested
    /// The phone hands over the QR code data generated for logging in the watch.
    case loginCode(Data)
    /// The watch returns the check code it got once the secure channel was established.
    case checkCode(UInt8)
    /// The watch has finished signing in and is now verified.
    case watchSignedIn
    /// The sender cancelled the linking, or it failed on its side.
    case cancelled
}

nonisolated extension WatchLinkMessage: CustomStringConvertible {
    // The login code contains the rendezvous secret, so only ever log the case names.
    var description: String {
        switch self {
        case .linkRequested: "linkRequested"
        case .loginCode: "loginCode"
        case .checkCode: "checkCode"
        case .watchSignedIn: "watchSignedIn"
        case .cancelled: "cancelled"
        }
    }
}
