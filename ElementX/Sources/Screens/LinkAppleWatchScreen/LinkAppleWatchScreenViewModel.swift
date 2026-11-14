//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias LinkAppleWatchScreenViewModelType = StateStoreViewModelV2<LinkAppleWatchScreenViewState, LinkAppleWatchScreenViewAction>

/// Links the user's Apple Watch as a new, verified device.
///
/// This is the existing device side of an MSC4108 login where the QR code is handed to the watch over
/// WatchConnectivity rather than displayed, and the watch's check code is returned the same way.
class LinkAppleWatchScreenViewModel: LinkAppleWatchScreenViewModelType, LinkAppleWatchScreenViewModelProtocol {
    private let clientProxy: ClientProxyProtocol
    private let appLockService: AppLockServiceProtocol
    private let watchLinkService: WatchLinkServiceProtocol

    private var currentOperation: LinkNewDeviceService.LinkMobileOperation?
    private var progressCancellable: AnyCancellable?
    private var oAuthResultTask: Task<Void, Never>?

    // The check code and its sender arrive independently (one from the watch, one from the SDK) in either order.
    private var checkCodeSender: CheckCodeSenderProxy?
    private var receivedCheckCode: UInt8?

    private let actionsSubject: PassthroughSubject<LinkAppleWatchScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<LinkAppleWatchScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(clientProxy: ClientProxyProtocol, appLockService: AppLockServiceProtocol, watchLinkService: WatchLinkServiceProtocol) {
        self.clientProxy = clientProxy
        self.appLockService = appLockService
        self.watchLinkService = watchLinkService

        super.init(initialViewState: .init(watchAvailability: .init(state: watchLinkService.statePublisher.value)))

        watchLinkService.statePublisher
            .map(LinkAppleWatchScreenViewState.WatchAvailability.init)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.watchAvailability, on: self)
            .store(in: &cancellables)

        watchLinkService.messagesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in self?.handle(message) }
            .store(in: &cancellables)

        Task { await checkQRCodeLoginSupport() }
    }

    // MARK: - Public

    override func process(viewAction: LinkAppleWatchScreenViewAction) {
        MXLog.info("View model: received view action: \(viewAction)")

        switch viewAction {
        case .link:
            Task { await verifyAndLink() }
        case .errorAction(let action):
            handleErrorAction(action)
        case .dismiss:
            stop()
            actionsSubject.send(.dismiss)
        }
    }

    func stop() {
        guard state.mode.isLinking else { return }

        MXLog.info("Stopping the Apple Watch linking.")
        _ = watchLinkService.send(.cancelled)
        resetOperation()
        state.mode = .idle
    }

    // MARK: - Private

    private func checkQRCodeLoginSupport() async {
        if await !clientProxy.isLoginWithQRCodeSupported {
            state.mode = .error(.notSupported)
        }
    }

    private func verifyAndLink() async {
        guard state.canStartLinking else { return }

        state.mode = .verifyingDeviceOwner

        switch await appLockService.verifyDeviceOwner(reason: L10n.screenLinkNewDeviceAuthenticationReasonIos) {
        case .verified, .unavailable:
            break
        case .appLockPINRequired:
            guard await verifyWithAppLockPIN() else {
                state.mode = .idle
                return
            }
        case .cancelled, .unverified:
            state.mode = .idle
            return
        case .error:
            state.mode = .error(.unknown)
            return
        }

        startLinking()
    }

    /// Asks the coordinator to verify the device owner with the App Lock PIN, suspending until it has a result.
    private func verifyWithAppLockPIN() async -> Bool {
        await withCheckedContinuation { continuation in
            actionsSubject.send(.verifyWithAppLockPIN(continuation))
        }
    }

    private func startLinking() {
        resetOperation()
        state.mode = .connecting

        let operation = clientProxy.linkNewDeviceService().linkMobileDevice()
        currentOperation = operation

        progressCancellable = operation.progressPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }

                if case .failure(let error) = completion {
                    handleError(error)
                }
            } receiveValue: { [weak self] progress in
                self?.handle(progress)
            }
    }

    private func handle(_ progress: LinkNewDeviceService.LinkMobileProgress) {
        MXLog.info("Linking Apple Watch progress changed to: \(progress)")
        guard state.mode.isLinking else { return }

        switch progress {
        case .starting:
            break
        case .qrReady(_, let data):
            if case .failure(let error) = watchLinkService.send(.loginCode(data)) {
                MXLog.error("Failed handing the login code to the watch: \(error)")
                resetOperation()
                state.mode = .idle
                state.bindings.alertInfo = AlertInfo(id: UUID(), title: UntranslatedL10n.screenLinkAppleWatchUnreachableIos)
            }
        case .qrScanned(let sender):
            checkCodeSender = sender
            sendCheckCodeIfReady()
        case .waitingForAuthorisation(let url, let continuationSender):
            state.mode = .waitingForAuthorisation
            requestOAuthAuthorisation(url: url, continuationSender: continuationSender)
        case .syncingSecrets:
            state.mode = .verifying
        case .done:
            MXLog.info("Apple Watch linked.")
            resetOperation()
            state.mode = .done
        }
    }

    private func handle(_ message: WatchLinkMessage) {
        switch message {
        case .linkRequested:
            // The user tapped set up on the watch while this screen was open, so carry on from there.
            if state.canStartLinking {
                Task { await verifyAndLink() }
            }
        case .checkCode(let code):
            receivedCheckCode = code
            sendCheckCodeIfReady()
        case .cancelled:
            guard state.mode.isLinking else { return }
            resetOperation()
            state.mode = .error(.cancelled)
        case .watchSignedIn:
            // The SDK reports done as well, this covers the watch getting there first.
            if state.mode.isLinking {
                resetOperation()
                state.mode = .done
            }
        case .loginCode:
            MXLog.error("Unexpected login code received from the watch.")
        }
    }

    private func sendCheckCodeIfReady() {
        guard let checkCodeSender, let receivedCheckCode else { return }
        self.checkCodeSender = nil

        Task { [weak self] in
            do {
                try await checkCodeSender.send(code: receivedCheckCode)
            } catch {
                MXLog.error("Failed sending the watch's check code: \(error)")
                self?.handleError(.invalidCheckCode)
            }
        }
    }

    private func requestOAuthAuthorisation(url: URL, continuationSender: ContinuationMessageSenderProxy) {
        // As with linking any other device there's no OAuth redirect, so the WAS always returns a cancellation
        // failure. Confirm the continuation straight away and let the progress publisher drive the state.
        Task { await continuationSender.confirm() }

        let (stream, continuation) = AsyncStream<Result<Void, OAuthError>>.makeStream()
        actionsSubject.send(.requestOAuthAuthorisation(url, continuation))

        oAuthResultTask = Task { [weak self] in
            for await result in stream {
                guard let self else { return }
                switch result {
                case .success, .failure(.userCancellation):
                    break // The state will be updated by the progress publisher.
                case .failure:
                    handleError(.unknown)
                }
            }
        }
    }

    private func handleError(_ error: QRCodeLoginError) {
        MXLog.error("Failed linking the Apple Watch: \(error)")
        _ = watchLinkService.send(.cancelled)
        resetOperation()

        state.mode = switch error {
        case .cancelled: .error(.cancelled)
        case .connectionInsecure, .invalidCheckCode: .error(.connectionNotSecure)
        case .declined: .error(.declined)
        case .linkingNotSupported: .error(.linkingNotSupported)
        case .expired: .error(.expired)
        case .slidingSyncNotAvailable: .error(.slidingSyncNotAvailable)
        case .deviceAlreadySignedIn: .error(.deviceAlreadySignedIn)
        case .invalidQRCode, .providerNotAllowed, .deviceNotSignedIn, .unknown: .error(.unknown)
        }
    }

    private func handleErrorAction(_ action: QRCodeErrorView.Action) {
        switch action {
        case .startOver:
            state.mode = .idle
        case .cancel, .openSettings, .signInManually:
            actionsSubject.send(.dismiss)
        }
    }

    private func resetOperation() {
        progressCancellable = nil
        oAuthResultTask?.cancel()
        oAuthResultTask = nil
        currentOperation?.closeRendezvousChannel()
        currentOperation = nil
        checkCodeSender = nil
        receivedCheckCode = nil
    }
}
