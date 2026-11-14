//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// A sheet showing a message's text so that the user can select and copy part of it.
struct TimelineItemTextSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let attributedString: AttributedString
    
    private var styledAttributedString: AttributedString {
        // Matches the timeline's defaults for anything the formatted body doesn't specify.
        var container = AttributeContainer()
        container.font = UIFont.preferredFont(forTextStyle: .body)
        container.foregroundColor = UIColor.compound.textPrimary
        return attributedString.mergingAttributes(container, mergePolicy: .keepCurrent)
    }
    
    var body: some View {
        ElementNavigationStack {
            ScrollView {
                MessageText(attributedString: styledAttributedString, allowsSelection: true)
                    .fixedSize(horizontal: false, vertical: true)
                    .tint(.compound.textLinkExternal)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.compound.bgCanvasDefault)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(UntranslatedL10n.actionSelectText)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.actionDone) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Previews

struct TimelineItemTextSelectionView_Previews: PreviewProvider, TestablePreview {
    static let attributedStringBuilder = AttributedStringBuilder(cacheKey: "TimelineItemTextSelectionView", mentionBuilder: MentionBuilder())
    static let formattedHTML = """
    Hey <a href="https://matrix.to/#/@alice:matrix.org">Alice</a>, the <b>Wi-Fi password</b> is <code>correct-horse-battery-staple</code>.\
    <blockquote>Can you send it again?</blockquote>
    """
    
    static var previews: some View {
        TimelineItemTextSelectionView(attributedString: AttributedString("Meet me at the station at 6pm, the code for the door is 4711."))
            .previewDisplayName("Plain text")
        
        if let attributedString = attributedStringBuilder.fromHTML(formattedHTML) {
            TimelineItemTextSelectionView(attributedString: attributedString)
                .previewDisplayName("Formatted text")
        }
    }
}
