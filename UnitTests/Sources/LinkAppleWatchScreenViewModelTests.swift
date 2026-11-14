//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementX
import Foundation
import MatrixRustSDKMocks
import Testing

@MainActor
class LinkAppleWatchScreenViewModelTests {
    var linkNewDeviceService: LinkNewDeviceServiceMock!
    var appLockService: AppLockServiceMock!
    var watchLinkService: WatchLinkServiceMock!
    var watchStateSubject: CurrentValueSubject<WatchLinkState, Never>!
    var watchMessagesSubject: PassthroughSubject<WatchLinkMessage, Never>!
    var progressSubject: CurrentValueSubject<LinkNewDeviceService.LinkMobileProgress, QRCodeLoginError>!

    var viewModel: LinkAppleWatchScreenViewModel!
    var context: LinkAppleWatchScreenViewModel.Context {
        viewModel.context
    }

    @Test("The screen can only start linking once the watch app is installed and reachable")
    func availability() async throws {
        setupViewModel(watchState: .init(isActivated: true, isPaired: false))
        #expect(context.viewState.watchAvailability == .notPaired)
        #expect(!context.viewState.canStartLinking)

        let deferred = deferFulfillment(context.observe(\.viewState.watchAvailability)) { $0 == .available }
        watchStateSubject.send(.reachableWatch)
        try await deferred.fulfill()
        #expect(context.viewState.canStartLinking)
    }

    @Test("Linking hands the login code to the watch, relays its check code and finishes once the secrets are synced")
    func link() async throws {
        setupViewModel()

        let deferredConnecting = deferFulfillment(context.observe(\.viewState.mode)) { $0 == .connecting }
        context.send(viewAction: .link)
        try await deferredConnecting.fulfill()
        #expect(appLockService.verifyDeviceOwnerReasonCalled)

        // The QR code data goes to the watch instead of being displayed.
        let qrData = Data("login-code".utf8)
        await waitForConfirmation("The login code is handed to the watch") { confirmation in
            watchLinkService.sendClosure = { message in
                if message == .loginCode(qrData) { confirmation() }
                return .success(())
            }
            progressSubject.send(.qrReady(LinkNewDeviceServiceMock.mockQRCodeImage, data: qrData))
        }

        // The check code may arrive from the watch before the SDK asks for it.
        let checkCodeSender = CheckCodeSenderSDKMock()
        await waitForConfirmation("The watch's check code is sent on") { confirmation in
            checkCodeSender.sendCodeClosure = { code in
                #expect(code == 42)
                confirmation()
            }
            watchMessagesSubject.send(.checkCode(42))
            progressSubject.send(.qrScanned(CheckCodeSenderProxy(underlyingSender: checkCodeSender)))
        }

        let deferredAction = deferFulfillment(viewModel.actionsPublisher) { $0.isRequestOAuthAuthorisation }
        progressSubject.send(.waitingForAuthorisation(verificationURL: .homeDirectory,
                                                      continuationSender: .init(underlyingSender: ContinuationMessageSenderSDKMock())))
        try await deferredAction.fulfill()
        #expect(context.viewState.mode == .waitingForAuthorisation)

        let deferredVerifying = deferFulfillment(context.observe(\.viewState.mode)) { $0 == .verifying }
        progressSubject.send(.syncingSecrets)
        try await deferredVerifying.fulfill()

        let deferredDone = deferFulfillment(context.observe(\.viewState.mode)) { $0 == .done }
        progressSubject.send(.done)
        try await deferredDone.fulfill()
    }

    @Test("An unreachable watch stops the linking and explains why")
    func unreachableWatch() async throws {
        setupViewModel()
        watchLinkService.sendReturnValue = .failure(.notReachable)

        let deferredConnecting = deferFulfillment(context.observe(\.viewState.mode)) { $0 == .connecting }
        context.send(viewAction: .link)
        try await deferredConnecting.fulfill()

        let deferredIdle = deferFulfillment(context.observe(\.viewState.mode)) { $0 == .idle }
        progressSubject.send(.qrReady(LinkNewDeviceServiceMock.mockQRCodeImage, data: Data("login-code".utf8)))
        try await deferredIdle.fulfill()
        #expect(context.alertInfo != nil)
    }

    @Test("The watch cancelling the linking shows the cancelled error")
    func watchCancellation() async throws {
        setupViewModel()

        let deferredConnecting = deferFulfillment(context.observe(\.viewState.mode)) { $0 == .connecting }
        context.send(viewAction: .link)
        try await deferredConnecting.fulfill()

        let deferredError = deferFulfillment(context.observe(\.viewState.mode)) { $0 == .error(.cancelled) }
        watchMessagesSubject.send(.cancelled)
        try await deferredError.fulfill()
    }

    @Test("Tapping set up on the watch starts linking when the screen is open")
    func linkRequestedFromWatch() async throws {
        setupViewModel()

        let deferredConnecting = deferFulfillment(context.observe(\.viewState.mode)) { $0 == .connecting }
        watchMessagesSubject.send(.linkRequested)
        try await deferredConnecting.fulfill()
        #expect(linkNewDeviceService.linkMobileDeviceCalled)
    }

    @Test("Dismissing while linking tells the watch to stop")
    func dismissWhileLinking() async throws {
        setupViewModel()

        let deferredConnecting = deferFulfillment(context.observe(\.viewState.mode)) { $0 == .connecting }
        context.send(viewAction: .link)
        try await deferredConnecting.fulfill()

        let deferredAction = deferFulfillment(viewModel.actionsPublisher) { $0.isDismiss }
        context.send(viewAction: .dismiss)
        try await deferredAction.fulfill()
        #expect(watchLinkService.sendReceivedInvocations.last == .cancelled)
    }

    @Test("The screen shows an error when the homeserver doesn't support linking with a QR code")
    func notSupported() async throws {
        setupViewModel(isLoginWithQRCodeSupported: false)

        let deferred = deferFulfillment(context.observe(\.viewState.mode)) { $0 == .error(.notSupported) }
        try await deferred.fulfill()
    }

    // MARK: - Helpers

    private func setupViewModel(isLoginWithQRCodeSupported: Bool = true, watchState: WatchLinkState = .reachableWatch) {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.underlyingIsLoginWithQRCodeSupported = isLoginWithQRCodeSupported

        progressSubject = .init(.starting)
        linkNewDeviceService = LinkNewDeviceServiceMock(.init(linkMobileOperation: .init(progressPublisher: progressSubject.asCurrentValuePublisher())))
        clientProxy.linkNewDeviceServiceReturnValue = linkNewDeviceService

        appLockService = AppLockServiceMock.mock()
        appLockService.verifyDeviceOwnerReasonReturnValue = .verified

        watchStateSubject = .init(watchState)
        watchMessagesSubject = .init()
        watchLinkService = WatchLinkServiceMock()
        watchLinkService.statePublisher = watchStateSubject.asCurrentValuePublisher()
        watchLinkService.messagesPublisher = watchMessagesSubject.eraseToAnyPublisher()
        watchLinkService.sendReturnValue = .success(())

        viewModel = LinkAppleWatchScreenViewModel(clientProxy: clientProxy,
                                                  appLockService: appLockService,
                                                  watchLinkService: watchLinkService)
    }
}

private extension WatchLinkState {
    static let reachableWatch = WatchLinkState(isActivated: true, isReachable: true, isPaired: true, isWatchAppInstalled: true)
}

private extension LinkAppleWatchScreenViewModelAction {
    var isRequestOAuthAuthorisation: Bool {
        switch self {
        case .requestOAuthAuthorisation: true
        default: false
        }
    }

    var isDismiss: Bool {
        switch self {
        case .dismiss: true
        default: false
        }
    }
}
