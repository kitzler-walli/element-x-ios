//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

// A watchOS version of Compound's `CompoundColors`, without the iOS only placeholder tokens and overrides.

extension Color {
    /// The colours used by Element as defined in Compound Design Tokens.
    static let compound = CompoundColors()
}

extension ShapeStyle where Self == Color {
    /// The colours used by Element as defined in Compound Design Tokens.
    static var compound: CompoundColors {
        Color.compound
    }
}

@dynamicMemberLookup
final class CompoundColors: Sendable {
    private let tokens = CompoundColorTokens()

    subscript(dynamicMember keyPath: KeyPath<CompoundColorTokens, Color>) -> Color {
        tokens[keyPath: keyPath]
    }
}
