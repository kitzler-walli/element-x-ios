//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import SwiftUI
import Testing

struct AttributedStringTests {
    @Test("Fixed size fonts are replaced with presentation intents")
    func replacingFontWithPresentationIntent() throws {
        // Given a string parsed from HTML that contains specific fixed size fonts.
        let boldString = "Bold"
        let originalString = try #require(AttributedStringBuilder(mentionBuilder: MentionBuilder())
            .fromHTML("Normal <b>\(boldString)</b> Normal."))
        
        // When replacing the font with a presentation intent.
        let string = originalString.replacingFontWithPresentationIntent()
        
        // Then the font should be removed with an inline presentation intent applied to the bold text.
        for run in string.runs {
            #expect(run.uiKit.font == nil, "The UIFont should have been removed.")
            #expect(run.font == nil, "No font should be in the run at all.")
            
            let substring = string[run.range]
            if String(substring.characters) == boldString {
                #expect(run.inlinePresentationIntent == .stronglyEmphasized, "The bold string should be bold.")
            } else {
                #expect(run.presentationIntent == nil, "The rest should be plain.")
            }
        }
    }
    
    @Test("Each paragraph takes the direction of its first strong character")
    func paragraphWritingDirections() {
        // Given a message mixing Persian and English paragraphs, one of them starting with digits.
        let string = NSMutableAttributedString(string: "سلام دوستان!\n۱۲ نفر آمدند\nOK باشه\nHello")
        
        // When applying the paragraph writing directions.
        string.applyParagraphWritingDirections()
        
        // Then each paragraph should follow its first letter, ignoring the digits.
        #expect(paragraphDirections(in: string) == [.rightToLeft, .rightToLeft, .leftToRight, .leftToRight])
    }
    
    @Test("Paragraphs without a strong character follow the one before them")
    func neutralParagraphWritingDirections() {
        // Given a Persian message with paragraphs that only contain emojis, digits or punctuation.
        let string = NSMutableAttributedString(string: "😂\nسلام\n😀😀\n۱۲۳۴\n!!!")
        
        // When applying the paragraph writing directions.
        string.applyParagraphWritingDirections()
        
        // Then they should all be right-to-left, including the leading emoji.
        #expect(paragraphDirections(in: string) == [.rightToLeft, .rightToLeft, .rightToLeft, .rightToLeft, .rightToLeft])
        
        // Given a message without any strong character.
        let neutralString = NSMutableAttributedString(string: "😂 123\n!!!")
        
        // When applying the paragraph writing directions.
        neutralString.applyParagraphWritingDirections()
        
        // Then it should be left to TextKit's natural direction.
        #expect(paragraphDirections(in: neutralString) == [.natural, .natural])
    }
    
    @Test("Existing paragraph styles are kept when applying the writing direction")
    func paragraphWritingDirectionKeepsStyle() throws {
        // Given a Persian paragraph that is already indented.
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = 12
        let string = NSMutableAttributedString(string: "سلام", attributes: [.paragraphStyle: paragraphStyle])
        
        // When applying the paragraph writing directions.
        string.applyParagraphWritingDirections()
        
        // Then the indentation should be kept alongside the new direction.
        let appliedStyle = try #require(string.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        #expect(appliedStyle.baseWritingDirection == .rightToLeft)
        #expect(appliedStyle.headIndent == 12)
    }
    
    @Test("Mention pills are written out as text, using the user ID when no display name is known")
    func plainTextWithMentions() throws {
        let attributedString = try #require(AttributedStringBuilder(mentionBuilder: MentionBuilder())
            .fromHTML("Hi <a href=\"https://matrix.to/#/@alice:matrix.org\">Alice</a>, ask @room in <a href=\"https://matrix.to/#/#room:matrix.org\">#room:matrix.org</a>."))
        let string = try NSAttributedString(attributedString, including: \.elementX)
        
        #expect(string.string.contains("\u{FFFC}"))
        #expect(string.plainTextWithMentions() == "Hi @alice:matrix.org, ask @room in #room:matrix.org.")
        #expect(string.plainTextWithMentions { $0 == "@alice:matrix.org" ? "Alice" : nil } == "Hi Alice, ask @room in #room:matrix.org.")
    }
    
    @Test("A user mention carrying a display name is written out with it")
    func plainTextWithDisplayNameMention() {
        let string = NSMutableAttributedString(string: "Hi ")
        let pill = NSMutableAttributedString(attachment: NSTextAttachment())
        pill.addAttributes([.MatrixUserID: "@bob:matrix.org", .MatrixUserDisplayName: "Bob"], range: NSRange(location: 0, length: pill.length))
        string.append(pill)
        
        #expect(string.plainTextWithMentions { _ in "Robert" } == "Hi Bob")
    }
    
    // MARK: - Helpers
    
    private func paragraphDirections(in string: NSAttributedString) -> [NSWritingDirection] {
        var directions = [NSWritingDirection]()
        (string.string as NSString).enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            let paragraphStyle = string.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
            directions.append(paragraphStyle?.baseWritingDirection ?? .natural)
        }
        return directions
    }
}
