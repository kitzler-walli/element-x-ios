//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Compound
import SwiftUI

struct LinkAppleWatchScreen: View {
    @Bindable var context: LinkAppleWatchScreenViewModel.Context

    var body: some View {
        switch context.viewState.mode {
        case .error(let errorState):
            QRCodeErrorView(errorState: errorState, canSignInManually: false) { action in
                context.send(viewAction: .errorAction(action))
            }
            .backgroundStyle(.compound.bgCanvasDefault)
        default:
            FullscreenDialog(topPadding: 24, horizontalPadding: 24) {
                mainContent
            } bottomContent: {
                buttons
            }
            .background()
            .backgroundStyle(.compound.bgSubtleSecondary)
            .navigationTitle(UntranslatedL10n.commonAppleWatchIos)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .alert(item: $context.alertInfo)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if context.viewState.mode == .done {
            TitleAndIcon(title: UntranslatedL10n.screenLinkAppleWatchDoneTitleIos,
                         subtitle: UntranslatedL10n.screenLinkAppleWatchDoneMessageIos,
                         icon: \.checkCircleSolid,
                         iconStyle: .successSolid)
        } else {
            VStack(spacing: 24) {
                TitleAndIcon(title: UntranslatedL10n.screenLinkAppleWatchReadyTitleIos,
                             subtitle: UntranslatedL10n.screenLinkAppleWatchReadyMessageIos,
                             icon: \.devices,
                             iconStyle: .default)

                if let message = context.viewState.availabilityMessage, !context.viewState.mode.isLinking {
                    Label(message, icon: \.info)
                        .font(.compound.bodyMD)
                        .foregroundStyle(.compound.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        switch context.viewState.mode {
        case .idle:
            Button(UntranslatedL10n.screenLinkAppleWatchSetUpActionIos) {
                context.send(viewAction: .link)
            }
            .buttonStyle(.compound(.primary))
            .disabled(!context.viewState.canStartLinking)
        case .verifyingDeviceOwner, .connecting, .waitingForAuthorisation, .verifying:
            Button { } label: {
                Label {
                    Text(progressTitle)
                } icon: {
                    ProgressView()
                        .tint(.compound.iconOnSolidPrimary)
                }
            }
            .buttonStyle(.compound(.primary))
            .disabled(true)
        case .done:
            Button(L10n.actionDone) {
                context.send(viewAction: .dismiss)
            }
            .buttonStyle(.compound(.primary))
        case .error:
            EmptyView() // Not reachable.
        }
    }

    private var progressTitle: String {
        switch context.viewState.mode {
        case .waitingForAuthorisation: UntranslatedL10n.screenLinkAppleWatchAuthorisingIos
        case .verifying: UntranslatedL10n.screenLinkAppleWatchVerifyingIos
        default: UntranslatedL10n.screenLinkAppleWatchConnectingIos
        }
    }

    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if context.viewState.mode != .done {
                Button(L10n.actionCancel) {
                    context.send(viewAction: .dismiss)
                }
            }
        }
    }
}

// MARK: - Previews

@available(iOS 26.0, *)
struct LinkAppleWatchScreen_Previews: PreviewProvider, TestablePreview {
    static let readyViewModel = makeViewModel(watchState: .init(isActivated: true, isReachable: true, isPaired: true, isWatchAppInstalled: true))
    static let notOpenViewModel = makeViewModel(watchState: .init(isActivated: true, isReachable: false, isPaired: true, isWatchAppInstalled: true))
    static let notInstalledViewModel = makeViewModel(watchState: .init(isActivated: true, isReachable: false, isPaired: true, isWatchAppInstalled: false))

    static var previews: some View {
        ElementNavigationStack {
            LinkAppleWatchScreen(context: readyViewModel.context)
        }
        .previewDisplayName("Ready")

        ElementNavigationStack {
            LinkAppleWatchScreen(context: notOpenViewModel.context)
        }
        .previewDisplayName("Watch app not open")

        ElementNavigationStack {
            LinkAppleWatchScreen(context: notInstalledViewModel.context)
        }
        .previewDisplayName("Watch app not installed")
    }

    static func makeViewModel(watchState: WatchLinkState) -> LinkAppleWatchScreenViewModel {
        let watchLinkService = WatchLinkServiceMock()
        watchLinkService.statePublisher = .init(watchState)
        watchLinkService.messagesPublisher = PassthroughSubject<WatchLinkMessage, Never>().eraseToAnyPublisher()

        return LinkAppleWatchScreenViewModel(clientProxy: ClientProxyMock(.init()),
                                             appLockService: AppLockServiceMock(),
                                             watchLinkService: watchLinkService)
    }
}
