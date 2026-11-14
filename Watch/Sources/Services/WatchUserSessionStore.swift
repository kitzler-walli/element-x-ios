//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

enum WatchUserSessionStoreError: Error {
    case noStoredSession
    case missingSessionData
    case failedRestoringSession
    case failedSettingUpSession
}

/// Persists the watch's single account in the keychain and restores it at launch.
final class WatchUserSessionStore {
    private let keychainController: KeychainControllerProtocol
    private let clientFactory: ClientFactoryProtocol
    private let appSettings: AppSettings
    private let appHooks: AppHooks

    var clientSessionDelegate: ClientSessionDelegate {
        keychainController
    }

    init(keychainController: KeychainControllerProtocol,
         clientFactory: ClientFactoryProtocol = ClientFactory(),
         appSettings: AppSettings,
         appHooks: AppHooks) {
        self.keychainController = keychainController
        self.clientFactory = clientFactory
        self.appSettings = appSettings
        self.appHooks = appHooks
    }

    /// Restores the stored account, if there is one.
    func restoreSession() async -> Result<WatchUserSession, WatchUserSessionStoreError> {
        guard let credentials = keychainController.restorationTokens().first else {
            return .failure(.noStoredSession)
        }

        MXLog.info("Restoring session for \(credentials.userID)")

        guard credentials.restorationToken.sessionDirectories.isNonTransientUserDataValid() else {
            MXLog.error("The crypto store is missing, removing the stored session for \(credentials.userID).")
            removeCredentials(credentials)
            return .failure(.missingSessionData)
        }

        do {
            let client = try await clientFactory.makeAppClient(credentials: credentials,
                                                               clientSessionDelegate: keychainController,
                                                               appSettings: appSettings,
                                                               appHooks: appHooks)
            let userSession = try await WatchUserSession(client: client,
                                                         sessionDirectories: credentials.restorationToken.sessionDirectories)
            return .success(userSession)
        } catch {
            MXLog.error("Failed restoring session for \(credentials.userID): \(error)")
            return .failure(.failedRestoringSession)
        }
    }

    /// Stores a freshly signed in client and wraps it in a session.
    func makeSession(for client: ClientProtocol, sessionDirectories: SessionDirectories, passphrase: Data) async -> Result<WatchUserSession, WatchUserSessionStoreError> {
        do {
            let userID = try client.userId()
            try keychainController.setRestorationToken(RestorationToken(session: client.session(),
                                                                    sessionDirectories: sessionDirectories,
                                                                    passphrase: passphrase,
                                                                    pusherNotificationClientIdentifier: nil),
                                                   forUsername: userID)

            MXLog.info("Set up session for user \(userID) at: \(sessionDirectories)")
            return try await .success(WatchUserSession(client: client, sessionDirectories: sessionDirectories))
        } catch {
            MXLog.error("Failed setting up the session: \(error)")
            return .failure(.failedSettingUpSession)
        }
    }

    /// Signs out of the account on the server and removes all of its local data.
    func logout(_ userSession: WatchUserSession) async {
        await userSession.stopSync()

        do {
            try await userSession.client.logout()
        } catch {
            MXLog.error("Failed logging out on the server, removing the local data anyway: \(error)")
        }

        if let credentials = keychainController.restorationTokens().first(where: { $0.userID == userSession.userID }) {
            removeCredentials(credentials)
        }
    }

    // MARK: - Private

    private func removeCredentials(_ credentials: KeychainCredentials) {
        keychainController.removeRestorationTokenForUsername(credentials.userID)
        try? credentials.restorationToken.sessionDirectories.delete()
    }
}
