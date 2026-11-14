//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import WatchConnectivity

/// The connection state between the iPhone app and the watch app.
nonisolated struct WatchLinkState: Equatable, Sendable {
    var isActivated = false
    var isReachable = false
    #if os(iOS)
    var isPaired = false
    var isWatchAppInstalled = false
    #else
    var isCompanionAppInstalled = false
    #endif

    /// Whether messages can be sent to the counterpart app right now.
    var canSendMessages: Bool {
        isActivated && isReachable
    }
}

enum WatchLinkServiceError: Error {
    case notActivated
    case notReachable
    case encodingFailed
}

// sourcery: AutoMockable
protocol WatchLinkServiceProtocol {
    var statePublisher: CurrentValuePublisher<WatchLinkState, Never> { get }
    var messagesPublisher: AnyPublisher<WatchLinkMessage, Never> { get }

    func activate()
    func send(_ message: WatchLinkMessage) -> Result<Void, WatchLinkServiceError>
}

/// A two-way WatchConnectivity channel between the iPhone app and the watch app.
final class WatchLinkService: NSObject, WatchLinkServiceProtocol {
    // WCSession is a per-process singleton that supports a single delegate, so this service is one too.
    static let shared = WatchLinkService()

    private let session: WCSession?
    private let stateSubject = CurrentValueSubject<WatchLinkState, Never>(.init())
    private let messagesSubject = PassthroughSubject<WatchLinkMessage, Never>()

    var statePublisher: CurrentValuePublisher<WatchLinkState, Never> {
        stateSubject.asCurrentValuePublisher()
    }

    var messagesPublisher: AnyPublisher<WatchLinkMessage, Never> {
        messagesSubject.eraseToAnyPublisher()
    }

    override private init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
    }

    /// Activates the session. Call this at launch so that messages sent while the app was in the background are delivered.
    func activate() {
        guard let session, session.activationState != .activated else { return }
        session.delegate = self
        session.activate()
    }

    func send(_ message: WatchLinkMessage) -> Result<Void, WatchLinkServiceError> {
        guard let session, session.activationState == .activated else { return .failure(.notActivated) }
        guard session.isReachable else { return .failure(.notReachable) }

        let data: Data
        do {
            data = try JSONEncoder().encode(message)
        } catch {
            MXLog.error("Failed encoding \(message): \(error)")
            return .failure(.encodingFailed)
        }

        MXLog.info("Sending \(message) to the counterpart app.")
        // WatchConnectivity calls the handler on a background queue, so it must not inherit the main actor.
        session.sendMessageData(data, replyHandler: nil) { @Sendable error in
            MXLog.error("Failed sending \(message) to the counterpart app: \(error)")
        }

        return .success(())
    }

    // MARK: - Private

    private func update(_ state: WatchLinkState) {
        guard state != stateSubject.value else { return }
        MXLog.info("Watch link state changed: \(state)")
        stateSubject.send(state)
    }

    private func receive(_ message: WatchLinkMessage) {
        MXLog.info("Received \(message) from the counterpart app.")
        messagesSubject.send(message)
    }
}

// MARK: - WCSessionDelegate

// The delegate is called on a background queue, so everything hops back to the main actor.
extension WatchLinkService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error {
            MXLog.error("Watch link activation failed: \(error)")
        }

        let state = WatchLinkState(session: session)
        Task { @MainActor in update(state) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let state = WatchLinkState(session: session)
        Task { @MainActor in update(state) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        guard let message = try? JSONDecoder().decode(WatchLinkMessage.self, from: messageData) else {
            MXLog.error("Received an unknown message from the counterpart app.")
            return
        }

        Task { @MainActor in receive(message) }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        let state = WatchLinkState(session: session)
        Task { @MainActor in update(state) }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // The user switched to another watch, activate again to talk to it.
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let state = WatchLinkState(session: session)
        Task { @MainActor in update(state) }
    }
    #else
    nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        let state = WatchLinkState(session: session)
        Task { @MainActor in update(state) }
    }
    #endif
}

private nonisolated extension WatchLinkState {
    init(session: WCSession) {
        isActivated = session.activationState == .activated
        isReachable = session.isReachable
        #if os(iOS)
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        #else
        isCompanionAppInstalled = session.isCompanionAppInstalled
        #endif
    }
}
