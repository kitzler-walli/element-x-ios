//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

/// A destination pushed on top of the room list.
enum WatchRoute: Hashable {
    case room(roomID: String)
    case settings
}

/// Owns the watch app's account and drives what is shown: onboarding until signed in, then the user's rooms.
@Observable
final class WatchAppCoordinator {
    enum State {
        case launching
        case onboarding(WatchOnboardingScreenViewModel)
        case signedIn(WatchSignedInState)
    }

    /// The screens shown while signed in, kept alive while they're on the navigation stack.
    @Observable
    final class WatchSignedInState {
        let userSession: WatchUserSession
        let roomListViewModel: WatchRoomListScreenViewModel
        var path: [WatchRoute] = [] {
            didSet { releaseUnusedViewModels() }
        }

        @ObservationIgnored private(set) var roomViewModels: [String: WatchRoomScreenViewModel] = [:]
        @ObservationIgnored private(set) var settingsViewModel: WatchSettingsScreenViewModel?

        init(userSession: WatchUserSession) {
            self.userSession = userSession
            roomListViewModel = WatchRoomListScreenViewModel(userSession: userSession)
        }

        func push(_ room: WatchRoomSummary) {
            if roomViewModels[room.id] == nil {
                roomViewModels[room.id] = WatchRoomScreenViewModel(room: room, userSession: userSession)
            }
            path.append(.room(roomID: room.id))
        }

        func pushSettings(makeViewModel: () -> WatchSettingsScreenViewModel) {
            settingsViewModel = makeViewModel()
            path.append(.settings)
        }

        private func releaseUnusedViewModels() {
            let visibleRoomIDs = Set(path.compactMap { if case .room(let roomID) = $0 { roomID } else { nil } })
            roomViewModels = roomViewModels.filter { visibleRoomIDs.contains($0.key) }
            if !path.contains(.settings) {
                settingsViewModel = nil
            }
        }
    }

    private(set) var state: State = .launching

    @ObservationIgnored private let appSettings: AppSettings
    @ObservationIgnored private let appHooks: AppHooks
    @ObservationIgnored private let userSessionStore: WatchUserSessionStore
    @ObservationIgnored private let watchLinkService: WatchLinkServiceProtocol
    @ObservationIgnored private var targetConfiguration: Target.ConfigurationResult?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var isActive = false

    init() {
        let appHooks = AppHooks()
        appHooks.setUp()
        self.appHooks = appHooks

        guard let userDefaults = TrackedUserDefaults(suiteName: AppSettings.suiteName) else {
            fatalError("Catastrophic error retrieving user defaults for \(AppSettings.suiteName)")
        }
        appSettings = AppSettings(store: userDefaults)

        targetConfiguration = Target.watchApp.configure(logLevel: appSettings.logLevel,
                                                        traceLogPacks: appSettings.traceLogPacks,
                                                        sentryURL: nil,
                                                        rageshakeURL: appSettings.bugReportRageshakeURL,
                                                        appHooks: appHooks)

        let keychainController = KeychainController(service: .sessions,
                                                    accessGroup: InfoPlistReader.main.keychainAccessGroupIdentifier)
        userSessionStore = WatchUserSessionStore(keychainController: keychainController,
                                                 appSettings: appSettings,
                                                 appHooks: appHooks)

        watchLinkService = WatchLinkService.shared
        watchLinkService.activate()

        MXLog.info("\(InfoPlistReader.main.bundleDisplayName) \(InfoPlistReader.main.bundleShortVersionString) (\(InfoPlistReader.main.bundleVersion))")
    }

    func start() async {
        guard case .launching = state else { return }

        switch await userSessionStore.restoreSession() {
        case .success(let userSession):
            await showSignedIn(userSession)
        case .failure(let error):
            MXLog.info("No session restored (\(error)), showing onboarding.")
            showOnboarding()
        }
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        isActive = scenePhase == .active
        guard case .signedIn(let signedInState) = state else { return }

        Task {
            if isActive {
                await signedInState.userSession.startSync()
            } else if scenePhase == .background {
                await signedInState.userSession.stopSync()
            }
        }
    }

    // MARK: - Private

    private func showOnboarding() {
        let authenticationService = WatchAuthenticationService(userSessionStore: userSessionStore,
                                                               appSettings: appSettings,
                                                               appHooks: appHooks)
        let viewModel = WatchOnboardingScreenViewModel(authenticationService: authenticationService,
                                                       watchLinkService: watchLinkService)

        viewModel.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .signedIn(let userSession):
                    Task { await self?.showSignedIn(userSession) }
                }
            }
            .store(in: &cancellables)

        state = .onboarding(viewModel)
    }

    private func showSignedIn(_ userSession: WatchUserSession) async {
        cancellables.removeAll()

        let signedInState = WatchSignedInState(userSession: userSession)

        signedInState.roomListViewModel.actionsPublisher
            .sink { [weak self, weak signedInState] action in
                guard let self, let signedInState else { return }

                switch action {
                case .openRoom(let room):
                    signedInState.push(room)
                case .openSettings:
                    signedInState.pushSettings { makeSettingsViewModel(userSession: userSession) }
                }
            }
            .store(in: &cancellables)

        state = .signedIn(signedInState)
        await userSession.startSync()
    }

    private func makeSettingsViewModel(userSession: WatchUserSession) -> WatchSettingsScreenViewModel {
        let viewModel = WatchSettingsScreenViewModel(userSession: userSession)

        viewModel.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .logout:
                    Task { await self?.logout(userSession) }
                }
            }
            .store(in: &cancellables)

        return viewModel
    }

    private func logout(_ userSession: WatchUserSession) async {
        MXLog.info("Signing out of the watch.")
        state = .launching
        await userSessionStore.logout(userSession)
        cancellables.removeAll()
        showOnboarding()
    }
}
