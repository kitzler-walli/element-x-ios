// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal nonisolated enum UntranslatedL10n {
  /// Select text
  internal static var actionSelectText: String { return UntranslatedL10n.tr("Untranslated", "action_select_text") }
  /// Apple Watch
  internal static var commonAppleWatchIos: String { return UntranslatedL10n.tr("Untranslated", "common_apple_watch_ios") }
  /// Install Element on your Apple Watch from the Watch app on this iPhone.
  internal static var screenLinkAppleWatchAppNotInstalledIos: String { return UntranslatedL10n.tr("Untranslated", "screen_link_apple_watch_app_not_installed_ios") }
  /// Approve the sign in to continue.
  internal static var screenLinkAppleWatchAuthorisingIos: String { return UntranslatedL10n.tr("Untranslated", "screen_link_apple_watch_authorising_ios") }
  /// Connecting to your Apple Watch…
  internal static var screenLinkAppleWatchConnectingIos: String { return UntranslatedL10n.tr("Untranslated", "screen_link_apple_watch_connecting_ios") }
  /// Element on your Apple Watch is signed in and verified.
  internal static var screenLinkAppleWatchDoneMessageIos: String { return UntranslatedL10n.tr("Untranslated", "screen_link_apple_watch_done_message_ios") }
  /// Your Apple Watch is ready
  internal static var screenLinkAppleWatchDoneTitleIos: String { return UntranslatedL10n.tr("Untranslated", "screen_link_apple_watch_done_title_ios") }
  /// Pair an Apple Watch with this iPhone to use Element on it.
  internal static var screenLinkAppleWatchNotPairedIos: String { return UntranslatedL10n.tr("Untranslated", "screen_link_apple_watch_not_paired_ios") }
  /// Open Element on your Apple Watch to continue.
  internal static var screenLinkAppleWatchOpenAppIos: String { return UntranslatedL10n.tr("Untranslated", "screen_link_apple_watch_open_app_ios") }
  /// Your Apple Watch gets its own secure, verified session, so you can keep chatting when your iPhone isn't with you.
  internal static var screenLinkAppleWatchReadyMessageIos: String { return UntranslatedL10n.tr("Untranslated", "screen_link_apple_watch_ready_message_ios") }
  /// Use Element on your Apple Watch
  internal static var screenLinkAppleWatchReadyTitleIos: String { return UntranslatedL10n.tr("Untranslated", "screen_link_apple_watch_ready_title_ios") }
  /// Set up Apple Watch
  internal static var screenLinkAppleWatchSetUpActionIos: String { return UntranslatedL10n.tr("Untranslated", "screen_link_apple_watch_set_up_action_ios") }
  /// Your Apple Watch can't be reached. Open Element on it and try again.
  internal static var screenLinkAppleWatchUnreachableIos: String { return UntranslatedL10n.tr("Untranslated", "screen_link_apple_watch_unreachable_ios") }
  /// Verifying your Apple Watch…
  internal static var screenLinkAppleWatchVerifyingIos: String { return UntranslatedL10n.tr("Untranslated", "screen_link_apple_watch_verifying_ios") }
  /// Approve the sign in on your iPhone.
  internal static var screenWatchOnboardingApproveIos: String { return UntranslatedL10n.tr("Untranslated", "screen_watch_onboarding_approve_ios") }
  /// Connecting…
  internal static var screenWatchOnboardingConnectingIos: String { return UntranslatedL10n.tr("Untranslated", "screen_watch_onboarding_connecting_ios") }
  /// Setup didn't complete. Try again.
  internal static var screenWatchOnboardingFailedIos: String { return UntranslatedL10n.tr("Untranslated", "screen_watch_onboarding_failed_ios") }
  /// Open Element on your iPhone, then try again.
  internal static var screenWatchOnboardingIphoneUnreachableIos: String { return UntranslatedL10n.tr("Untranslated", "screen_watch_onboarding_iphone_unreachable_ios") }
  /// Set up Element using your iPhone.
  internal static var screenWatchOnboardingMessageIos: String { return UntranslatedL10n.tr("Untranslated", "screen_watch_onboarding_message_ios") }
  /// Set up with iPhone
  internal static var screenWatchOnboardingRequestActionIos: String { return UntranslatedL10n.tr("Untranslated", "screen_watch_onboarding_request_action_ios") }
  /// Element
  internal static var screenWatchOnboardingTitleIos: String { return UntranslatedL10n.tr("Untranslated", "screen_watch_onboarding_title_ios") }
  /// Verifying…
  internal static var screenWatchOnboardingVerifyingIos: String { return UntranslatedL10n.tr("Untranslated", "screen_watch_onboarding_verifying_ios") }
  /// Continue on your iPhone.
  internal static var screenWatchOnboardingWaitingIos: String { return UntranslatedL10n.tr("Untranslated", "screen_watch_onboarding_waiting_ios") }
  /// Reply
  internal static var screenWatchRoomReplyPlaceholderIos: String { return UntranslatedL10n.tr("Untranslated", "screen_watch_room_reply_placeholder_ios") }
  /// This removes Element from this Apple Watch. Your iPhone stays signed in.
  internal static var screenWatchSettingsSignOutMessageIos: String { return UntranslatedL10n.tr("Untranslated", "screen_watch_settings_sign_out_message_ios") }
  /// Untranslated
  internal static var untranslated: String { return UntranslatedL10n.tr("Untranslated", "untranslated") }
  /// Plural format key: "%#@VARIABLE@"
  internal static func untranslatedPlural(_ p1: Int) -> String {
    return UntranslatedL10n.tr("Untranslated", "untranslated_plural", p1)
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

nonisolated extension UntranslatedL10n {
  static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    // No need to check languages, we always default to en for untranslated strings
    guard let bundle = Bundle.lprojBundle(for: "en") else { return key }
    let format = NSLocalizedString(key, tableName: table, bundle: bundle, comment: "")
    return String(format: format, locale: Locale(identifier: "en"), arguments: args)
  }
}

// swiftlint:enable all
