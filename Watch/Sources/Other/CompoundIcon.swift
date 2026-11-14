//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

// A watchOS version of Compound's `CompoundIcon` with the same API, without the iOS only font reflection.

extension Image {
    /// The icons used by Element as defined in Compound Design Tokens.
    static let compound = CompoundIcons()
}

struct CompoundIcon: View {
    /// The size of the icon.
    enum Size {
        case xSmall
        case small
        case medium
        case custom(CGFloat)

        var value: CGFloat {
            switch self {
            case .xSmall: 16
            case .small: 20
            case .medium: 24
            case .custom(let size): size
            }
        }
    }

    private let image: Image
    @ScaledMetric private var size: CGFloat

    /// Creates a 24pt icon that scales with Dynamic Type.
    init(_ icon: KeyPath<CompoundIcons, Image>) {
        self.init(icon, size: .medium, relativeTo: .compound.bodyLG)
    }

    /// Creates an icon of the given size. The font is accepted for parity with iOS, the icon scales relative to the body style.
    init(_ icon: KeyPath<CompoundIcons, Image>, size: Size, relativeTo font: Font) {
        image = .compound[keyPath: icon]
        _size = ScaledMetric(wrappedValue: size.value, relativeTo: .body)
    }

    var body: some View {
        image
            .resizable()
            .frame(width: size, height: size)
    }
}

extension Label where Title == Text, Icon == CompoundIcon {
    /// Creates a label with an icon from Compound and a title generated from a string.
    init(_ title: some StringProtocol, icon: KeyPath<CompoundIcons, Image>) {
        self.init {
            Text(title)
        } icon: {
            CompoundIcon(icon)
        }
    }
}
