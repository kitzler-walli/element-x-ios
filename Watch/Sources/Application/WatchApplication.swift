//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

@main
struct WatchApplication: App {
    @State private var appCoordinator = WatchAppCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRootView(coordinator: appCoordinator)
                .task { await appCoordinator.start() }
                .onChange(of: scenePhase, initial: true) {
                    appCoordinator.handleScenePhase(scenePhase)
                }
        }
    }
}

/// Shows the screens for the coordinator's current state.
struct WatchRootView: View {
    let coordinator: WatchAppCoordinator

    var body: some View {
        switch coordinator.state {
        case .launching:
            ProgressView()
        case .onboarding(let viewModel):
            WatchOnboardingScreen(context: viewModel.context)
        case .signedIn(let signedInState):
            WatchSignedInView(signedInState: signedInState)
        }
    }
}

private struct WatchSignedInView: View {
    @Bindable var signedInState: WatchAppCoordinator.WatchSignedInState

    var body: some View {
        NavigationStack(path: $signedInState.path) {
            WatchRoomListScreen(context: signedInState.roomListViewModel.context)
                .navigationDestination(for: WatchRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: WatchRoute) -> some View {
        switch route {
        case .room(let roomID):
            if let viewModel = signedInState.roomViewModels[roomID] {
                WatchRoomScreen(context: viewModel.context)
            }
        case .settings:
            if let viewModel = signedInState.settingsViewModel {
                WatchSettingsScreen(context: viewModel.context)
            }
        }
    }
}
