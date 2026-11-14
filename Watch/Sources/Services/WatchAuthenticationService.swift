//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

enum WatchLoginProgress: Equatable, CustomStringConvertible {
    case starting
    /// The secure channel is up, the check code must reach the phone to continue.
    case establishingSecureChannel(checkCode: UInt8)
    /// The user needs to approve the sign in on the phone, typing the user code if the server doesn't fill it in.
    case waitingForApproval(userCode: String)
    /// The phone is sending its secrets, verifying the watch.
    case syncingSecrets

    // The check code is part of the secure channel set up, keep it out of the logs.
    var description: String {
        switch self {
        case .starting: "starting"
        case .establishingSecureChannel: "establishingSecureChannel"
        case .waitingForApproval: "waitingForApproval"
        case .syncingSecrets: "syncingSecrets"
        }
    }
}

enum WatchAuthenticationServiceError: Error, Equatable {
    case invalidLoginCode
    case cancelled
    case declined
    case expired
    case notSupported
    case failedSettingUpSession
    case unknown
}

/// Signs the watch in as a new device using the login code handed over by the phone (MSC4108).
///
/// The SDK does the verification as part of the login: once the phone has sent its secrets the
/// watch is cross-signed and can read the account's history from key backup.
final class WatchAuthenticationService {
    private let userSessionStore: WatchUserSessionStore
    private let clientFactory: ClientFactoryProtocol
    private let encryptionKeyProvider: EncryptionKeyProviderProtocol
    private let appSettings: AppSettings
    private let appHooks: AppHooks

    init(userSessionStore: WatchUserSessionStore,
         clientFactory: ClientFactoryProtocol = ClientFactory(),
         encryptionKeyProvider: EncryptionKeyProviderProtocol = EncryptionKeyProvider(),
         appSettings: AppSettings,
         appHooks: AppHooks) {
        self.userSessionStore = userSessionStore
        self.clientFactory = clientFactory
        self.encryptionKeyProvider = encryptionKeyProvider
        self.appSettings = appSettings
        self.appHooks = appHooks
    }

    /// Logs in with the QR code data from the phone, reporting the progress along the way.
    ///
    /// Cancelling the calling task closes the rendezvous channel.
    func loginWithQRCode(data: Data, progress: @escaping @MainActor (WatchLoginProgress) -> Void) async -> Result<WatchUserSession, WatchAuthenticationServiceError> {
        let qrData: QrCodeData
        do {
            qrData = try QrCodeData.fromBytes(bytes: data)
        } catch {
            MXLog.error("Failed decoding the login code: \(error)")
            return .failure(.invalidLoginCode)
        }

        guard let serverNameOrBaseURL = qrData.baseUrl() ?? qrData.serverName() else {
            MXLog.error("The login code doesn't contain a homeserver.")
            return .failure(.invalidLoginCode)
        }

        let sessionDirectories = SessionDirectories()
        let passphrase = encryptionKeyProvider.generateKey()

        let listener = SDKListener<QrLoginProgress>.onMainActor { rustProgress in
            guard let watchProgress = WatchLoginProgress(rustProgress: rustProgress) else { return }
            MXLog.info("Login progress changed to: \(watchProgress)")
            progress(watchProgress)
        }

        do {
            let client = try await clientFactory.makeAuthenticationClient(serverNameOrBaseURL: serverNameOrBaseURL,
                                                                          sessionDirectories: sessionDirectories,
                                                                          passphrase: passphrase,
                                                                          clientSessionDelegate: userSessionStore.clientSessionDelegate,
                                                                          appSettings: appSettings,
                                                                          appHooks: appHooks)
            let handler = client.newLoginWithQrCodeHandler(oauthConfiguration: appSettings.oAuthConfiguration.rustValue)
            let sdkTask = try handler.scan(qrCodeData: qrData, progressListener: listener)
            try await withTaskCancellationHandler(operation: sdkTask.wait, onCancel: sdkTask.cancel)

            switch await userSessionStore.makeSession(for: client, sessionDirectories: sessionDirectories, passphrase: passphrase) {
            case .success(let userSession):
                return .success(userSession)
            case .failure:
                try? sessionDirectories.delete()
                return .failure(.failedSettingUpSession)
            }
        } catch let error as HumanQrLoginError {
            MXLog.error("QR code login failed: \(error)")
            try? sessionDirectories.delete()
            return .failure(.init(rustError: error))
        } catch {
            MXLog.error("QR code login failed with an unknown error: \(error)")
            try? sessionDirectories.delete()
            return .failure(Task.isCancelled ? .cancelled : .unknown)
        }
    }
}

private extension WatchLoginProgress {
    init?(rustProgress: QrLoginProgress) {
        switch rustProgress {
        case .starting:
            self = .starting
        case .establishingSecureChannel(let checkCode, _):
            self = .establishingSecureChannel(checkCode: checkCode)
        case .waitingForToken(let userCode):
            self = .waitingForApproval(userCode: userCode)
        case .syncingSecrets:
            self = .syncingSecrets
        case .done:
            return nil // The session still needs setting up, which the caller reports by returning.
        }
    }
}

private extension WatchAuthenticationServiceError {
    init(rustError: HumanQrLoginError) {
        self = switch rustError {
        case .Cancelled: .cancelled
        case .Declined: .declined
        case .Expired, .NotFound: .expired
        case .LinkingNotSupported, .SlidingSyncNotAvailable: .notSupported
        case .UnsupportedQrCodeType, .OtherDeviceNotSignedIn: .invalidLoginCode
        default: .unknown
        }
    }
}
