//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import ElementCall
@testable import ElementX
import SwiftUI
import Testing

@MainActor
struct CallFlowCoordinatorTests {
    private let navigationRootCoordinator = NavigationRootCoordinator()
    private let clientProxy: ClientProxyMock
    private let elementCallService = ElementCallServiceMock(.init())
    private let aliceSession: UserSessionMock
    private let sessionsSubject: CurrentValueSubject<[UserSessionProtocol], Never>
    private let userSessionManager: UserSessionManagerMock
    private let elementCallManager = ElementCallManagerMock()
    private let callFlowCoordinator: CallFlowCoordinator
    
    init() {
        clientProxy = makeAliceClientProxy()
        aliceSession = makeAliceSession(clientProxy: clientProxy, elementCallService: elementCallService)
        sessionsSubject = .init([aliceSession])
        userSessionManager = UserSessionManagerMock(.init(userSessions: sessionsSubject))
        
        let windowManager = WindowManagerMock()
        windowManager.mainWindow = UIWindow()
        
        callFlowCoordinator = CallFlowCoordinator(parameters: .init(navigationRootCoordinator: navigationRootCoordinator,
                                                                    userSessionManager: userSessionManager,
                                                                    elementCallManager: elementCallManager,
                                                                    windowManager: windowManager,
                                                                    analytics: AnalyticsServiceMock(.init())))
        callFlowCoordinator.start()
    }
    
    @Test("A web call opens on the root overlay, after asking its account's service for a native call")
    func webCallOpensOnRootOverlay() async {
        await waitForConfirmation { confirmation in
            elementCallService.setupCallSessionRoomIDRoomDisplayNameIsVideoKindClosure = { _, _, _, _ in confirmation() }
            callFlowCoordinator.presentCall(roomProxy: room("1"), isVoiceCall: false, answeredFromCallKit: false, userSession: aliceSession)
        }
        
        #expect(navigationRootCoordinator.overlayCoordinator is CallScreenCoordinator)
        #expect(elementCallService.handleNativeCallRequestRoomProxyIsVoiceCallAnsweredFromCallKitCallsCount == 1)
    }
    
    @Test("With native calls on, a call without a native stack is dropped instead of opening the web view")
    func callWithoutNativeStackIsDropped() {
        let appSettings = AppSettings.volatile()
        appSettings.nativeCallEnabled = true
        let userSession = UserSessionMock(.init(clientProxy: clientProxy,
                                                userSettings: appSettings.userSettings(for: clientProxy.userID),
                                                elementCallService: elementCallService))
        
        callFlowCoordinator.presentCall(roomProxy: room("1"), isVoiceCall: false, answeredFromCallKit: true, userSession: userSession)
        
        #expect(navigationRootCoordinator.overlayCoordinator == nil)
        #expect(elementCallManager.dropAnsweredCallUserIDRoomIDReceivedArguments?.userID == "@alice:matrix.org")
        #expect(elementCallManager.dropAnsweredCallUserIDRoomIDReceivedArguments?.roomID == "1")
    }
    
    @Test("Presenting the ongoing call again keeps its screen")
    func sameCallKeepsScreen() throws {
        callFlowCoordinator.presentCall(roomProxy: room("1"), isVoiceCall: false, answeredFromCallKit: false, userSession: aliceSession)
        let first = try #require(navigationRootCoordinator.overlayCoordinator as? CallScreenCoordinator)
        
        callFlowCoordinator.presentCall(roomProxy: room("1"), isVoiceCall: false, answeredFromCallKit: false, userSession: aliceSession)
        
        #expect(navigationRootCoordinator.overlayCoordinator === first)
        #expect(!elementCallService.tearDownCallSessionRoomIDCalled)
    }
    
    @Test("A call in another room replaces the current one and ends it")
    func otherCallReplacesCurrent() throws {
        callFlowCoordinator.presentCall(roomProxy: room("1"), isVoiceCall: false, answeredFromCallKit: false, userSession: aliceSession)
        let first = try #require(navigationRootCoordinator.overlayCoordinator as? CallScreenCoordinator)
        
        callFlowCoordinator.presentCall(roomProxy: room("2"), isVoiceCall: false, answeredFromCallKit: false, userSession: aliceSession)
        
        #expect(navigationRootCoordinator.overlayCoordinator !== first)
        #expect(navigationRootCoordinator.overlayCoordinator is CallScreenCoordinator)
        #expect(elementCallService.tearDownCallSessionRoomIDReceivedInvocations == ["1"])
    }
    
    @Test("A replaced call's late end leaves the call that replaced it open")
    func replacedCallCannotCloseReplacement() async throws {
        let firstRoom = room("1")
        let firstWidgetDriver = try #require(firstRoom.elementCallWidgetDriverDeviceIDReturnValue as? ElementCallWidgetDriverMock)
        let firstWidgetActions = PassthroughSubject<ElementCallWidgetDriverAction, Never>()
        firstWidgetDriver.actions = firstWidgetActions.eraseToAnyPublisher()
        
        callFlowCoordinator.presentCall(roomProxy: firstRoom, isVoiceCall: false, answeredFromCallKit: false, userSession: aliceSession)
        let first = try #require(navigationRootCoordinator.overlayCoordinator as? CallScreenCoordinator)
        callFlowCoordinator.presentCall(roomProxy: room("2"), isVoiceCall: false, answeredFromCallKit: false, userSession: aliceSession)
        let second = try #require(navigationRootCoordinator.overlayCoordinator as? CallScreenCoordinator)
        
        await waitForConfirmation(expectedCount: 0, timeout: .milliseconds(500)) { confirmation in
            elementCallService.tearDownCallSessionRoomIDClosure = { _ in confirmation() }
            firstWidgetActions.send(.callEnded)
        }
        
        #expect(navigationRootCoordinator.overlayCoordinator === second)
        #expect(elementCallService.tearDownCallSessionRoomIDReceivedInvocations == ["1"])
        // The replaced screen has to outlive the wait, or its late dismiss never fires.
        withExtendedLifetime(first) { }
    }
    
    @Test("A call whose screen was closed elsewhere opens a new screen")
    func callClosedElsewhereOpensAgain() throws {
        callFlowCoordinator.presentCall(roomProxy: room("1"), isVoiceCall: false, answeredFromCallKit: false, userSession: aliceSession)
        let first = try #require(navigationRootCoordinator.overlayCoordinator as? CallScreenCoordinator)
        navigationRootCoordinator.setOverlayCoordinator(nil)
        
        callFlowCoordinator.presentCall(roomProxy: room("1"), isVoiceCall: false, answeredFromCallKit: false, userSession: aliceSession)
        
        #expect(navigationRootCoordinator.overlayCoordinator is CallScreenCoordinator)
        #expect(navigationRootCoordinator.overlayCoordinator !== first)
    }
    
    @Test("Minimizing a web call without picture in picture ends it")
    func minimizeWithoutPictureInPictureEndsCall() {
        callFlowCoordinator.presentCall(roomProxy: room("1"), isVoiceCall: false, answeredFromCallKit: false, userSession: aliceSession)
        
        callFlowCoordinator.minimizeCall()
        
        #expect(navigationRootCoordinator.overlayCoordinator == nil)
        #expect(elementCallService.tearDownCallSessionRoomIDReceivedRoomID == "1")
    }
    
    @Test("A call by account opens with that account's session", arguments: [true, false])
    func callOpensWithAccountSession(answeredFromCallKit: Bool) async {
        await waitForConfirmation { confirmation in
            elementCallService.setupCallSessionRoomIDRoomDisplayNameIsVideoKindClosure = { _, _, _, _ in confirmation() }
            callFlowCoordinator.presentCall(userID: "@alice:matrix.org", roomID: "1", isVoiceCall: false, answeredFromCallKit: answeredFromCallKit)
        }
        
        #expect(navigationRootCoordinator.overlayCoordinator is CallScreenCoordinator)
        #expect(elementCallService.setupCallSessionRoomIDRoomDisplayNameIsVideoKindReceivedArguments?.roomID == "1")
        #expect(!elementCallManager.dropAnsweredCallUserIDRoomIDCalled)
    }
    
    @Test("A call for an account that isn't signed in is dropped", arguments: [true, false])
    func signedOutAccountCallIsDropped(answeredFromCallKit: Bool) {
        userSessionManager.userIDs = []
        
        callFlowCoordinator.presentCall(userID: "@alice:matrix.org", roomID: "1", isVoiceCall: false, answeredFromCallKit: answeredFromCallKit)
        
        #expect(navigationRootCoordinator.overlayCoordinator == nil)
        #expect(elementCallManager.dropAnsweredCallUserIDRoomIDCalled == answeredFromCallKit)
        #expect(!elementCallService.tearDownCallSessionRoomIDCalled)
        #expect(!userSessionManager.sessionForCalled, "An account that isn't signed in has no session to wait for")
    }
    
    @Test("An answered call in a room that isn't joined is dropped for its account")
    func unjoinedRoomCallIsDropped() async {
        await waitForConfirmation { confirmation in
            elementCallManager.dropAnsweredCallUserIDRoomIDClosure = { _, _ in confirmation() }
            callFlowCoordinator.presentCall(userID: "@alice:matrix.org", roomID: "!unknown:matrix.org", isVoiceCall: false, answeredFromCallKit: true)
        }
        
        #expect(elementCallManager.dropAnsweredCallUserIDRoomIDReceivedArguments?.userID == "@alice:matrix.org")
        #expect(elementCallManager.dropAnsweredCallUserIDRoomIDReceivedArguments?.roomID == "!unknown:matrix.org")
        #expect(!elementCallService.tearDownCallSessionRoomIDCalled)
        #expect(navigationRootCoordinator.overlayCoordinator == nil)
    }
    
    @Test("A call held for its account opens once the account's session is live")
    func pendingCallOpensWithSession() async {
        sessionsSubject.send([])
        callFlowCoordinator.presentCall(userID: "@alice:matrix.org", roomID: "1", isVoiceCall: false, answeredFromCallKit: true)
        #expect(navigationRootCoordinator.overlayCoordinator == nil)
        
        await waitForConfirmation { confirmation in
            elementCallService.setupCallSessionRoomIDRoomDisplayNameIsVideoKindClosure = { _, _, _, _ in confirmation() }
            sessionsSubject.send([aliceSession])
        }
        
        #expect(navigationRootCoordinator.overlayCoordinator is CallScreenCoordinator)
    }
    
    @Test("A held call opens only after its session is set up")
    func pendingCallWaitsForSessionSetup() async {
        sessionsSubject.send([])
        callFlowCoordinator.presentCall(userID: "@alice:matrix.org", roomID: "1", isVoiceCall: false, answeredFromCallKit: true)
        
        await waitForConfirmation { confirmation in
            elementCallService.handleNativeCallRequestRoomProxyIsVoiceCallAnsweredFromCallKitClosure = { _, _, answeredFromCallKit in
                #expect(answeredFromCallKit, "The native stack takes over the call answered through CallKit")
                confirmation()
                return true
            }
            sessionsSubject.send([aliceSession])
            #expect(!elementCallService.handleNativeCallRequestRoomProxyIsVoiceCallAnsweredFromCallKitCalled, "AppCoordinator hands the session's service the native stack right after adding it")
        }
        
        #expect(!(navigationRootCoordinator.overlayCoordinator is CallScreenCoordinator))
    }
    
    @Test("A held call is checked again when it opens")
    func pendingCallIsRecheckedOnOpen() async {
        // Given a call held until its account's session is live.
        sessionsSubject.send([])
        callFlowCoordinator.presentCall(userID: "@alice:matrix.org", roomID: "1", isVoiceCall: false, answeredFromCallKit: true)
        
        // When the account signs out as its session appears, then the call is dropped.
        await waitForConfirmation { confirmation in
            elementCallManager.dropAnsweredCallUserIDRoomIDClosure = { _, _ in confirmation() }
            sessionsSubject.send([aliceSession])
            userSessionManager.userIDs = []
        }
        
        #expect(elementCallManager.dropAnsweredCallUserIDRoomIDReceivedArguments?.roomID == "1")
        #expect(navigationRootCoordinator.overlayCoordinator == nil)
    }
    
    @Test("A newer held call drops the older one")
    func newerPendingCallDropsOlder() async {
        sessionsSubject.send([])
        callFlowCoordinator.presentCall(userID: "@alice:matrix.org", roomID: "1", isVoiceCall: false, answeredFromCallKit: true)
        callFlowCoordinator.presentCall(userID: "@alice:matrix.org", roomID: "2", isVoiceCall: false, answeredFromCallKit: true)
        
        #expect(elementCallManager.dropAnsweredCallUserIDRoomIDReceivedInvocations.map(\.roomID) == ["1"])
        
        await waitForConfirmation { confirmation in
            elementCallService.setupCallSessionRoomIDRoomDisplayNameIsVideoKindClosure = { _, _, _, _ in confirmation() }
            sessionsSubject.send([aliceSession])
        }
        
        #expect(elementCallService.setupCallSessionRoomIDRoomDisplayNameIsVideoKindReceivedArguments?.roomID == "2")
    }
    
    @Test("Ending an account's calls ends its web call and leaves other accounts' calls alone")
    func webCallEndsOnlyWithItsAccount() async {
        // Given Alice's web call, which outlives a change of root.
        await waitForConfirmation { confirmation in
            elementCallService.setupCallSessionRoomIDRoomDisplayNameIsVideoKindClosure = { _, _, _, _ in confirmation() }
            callFlowCoordinator.presentCall(roomProxy: room("1"), isVoiceCall: false, answeredFromCallKit: false, userSession: aliceSession)
        }
        
        navigationRootCoordinator.setRootCoordinator(PlaceholderScreenCoordinator(hideBrandChrome: false))
        #expect(navigationRootCoordinator.overlayCoordinator is CallScreenCoordinator)
        #expect(!elementCallService.tearDownCallSessionRoomIDCalled)
        
        // When another account ends its calls, then Alice's call stays.
        await callFlowCoordinator.endCalls(userID: "@bob:matrix.org")
        #expect(navigationRootCoordinator.overlayCoordinator is CallScreenCoordinator)
        
        // When Alice's account ends its calls, then hers ends.
        await callFlowCoordinator.endCalls(userID: "@alice:matrix.org")
        #expect(navigationRootCoordinator.overlayCoordinator == nil)
        #expect(elementCallService.tearDownCallSessionRoomIDReceivedRoomID == "1", "A call left ongoing would make every later call count as busy")
    }
    
    @Test("A leaving account's calls are dropped until its session changes")
    func blockedAccountDropsCallsUntilSessionChange() async {
        await callFlowCoordinator.endCalls(userID: "@alice:matrix.org")
        
        callFlowCoordinator.presentCall(userID: "@alice:matrix.org", roomID: "1", isVoiceCall: false, answeredFromCallKit: false)
        #expect(!elementCallManager.dropAnsweredCallUserIDRoomIDCalled)
        #expect(navigationRootCoordinator.overlayCoordinator == nil)
        
        sessionsSubject.send([aliceSession])
        callFlowCoordinator.presentCall(userID: "@alice:matrix.org", roomID: "1", isVoiceCall: false, answeredFromCallKit: true)
        #expect(elementCallManager.dropAnsweredCallUserIDRoomIDReceivedInvocations.map(\.roomID) == ["1"])
        
        await waitForConfirmation { confirmation in
            elementCallService.setupCallSessionRoomIDRoomDisplayNameIsVideoKindClosure = { _, _, _, _ in confirmation() }
            sessionsSubject.send([makeAliceSession(elementCallService: elementCallService)])
            callFlowCoordinator.presentCall(userID: "@alice:matrix.org", roomID: "1", isVoiceCall: false, answeredFromCallKit: true)
        }
        
        #expect(navigationRootCoordinator.overlayCoordinator is CallScreenCoordinator)
    }
    
    @Test("Ending an account's calls drops its held call")
    func endCallsDropsPendingCall() async {
        sessionsSubject.send([])
        callFlowCoordinator.presentCall(userID: "@alice:matrix.org", roomID: "1", isVoiceCall: false, answeredFromCallKit: true)
        
        await callFlowCoordinator.endCalls(userID: "@alice:matrix.org")
        
        #expect(elementCallManager.dropAnsweredCallUserIDRoomIDReceivedArguments?.roomID == "1")
        
        await waitForConfirmation(expectedCount: 0, timeout: .milliseconds(500)) { confirmation in
            elementCallService.setupCallSessionRoomIDRoomDisplayNameIsVideoKindClosure = { _, _, _, _ in confirmation() }
            sessionsSubject.send([aliceSession])
        }
    }
    
    // MARK: - Native call stack
    
    @Test("Setting the native call service turns its stack on")
    func nativeStackTurnsOn() {
        callFlowCoordinator.setNativeCallService(elementCallService)
        
        #expect(elementCallService.setNativeCallStackEnabledReceivedInvocations == [true])
    }
    
    @Test("Clearing the native call service turns its stack off")
    func nativeStackTurnsOffWhenCleared() {
        callFlowCoordinator.setNativeCallService(elementCallService)
        
        callFlowCoordinator.setNativeCallService(nil)
        
        #expect(elementCallService.setNativeCallStackEnabledReceivedInvocations == [true, false])
    }
    
    @Test("A new native call service turns the old stack off before turning its own on")
    func nativeStackMovesToNewService() {
        let bobService = ElementCallServiceMock(.init(userID: "@bob:matrix.org"))
        var toggles: [String] = []
        elementCallService.setNativeCallStackEnabledClosure = { toggles.append("alice \($0)") }
        bobService.setNativeCallStackEnabledClosure = { toggles.append("bob \($0)") }
        
        callFlowCoordinator.setNativeCallService(elementCallService)
        callFlowCoordinator.setNativeCallService(bobService)
        
        #expect(toggles == ["alice true", "alice false", "bob true"])
    }
    
    @Test("Clearing the native call service closes the native call screen at once")
    func clearingNativeServiceClosesScreen() throws {
        // Given a native call screen for a service whose stack is up.
        let appSettings = AppSettings.volatile()
        appSettings.nativeCallEnabled = true
        let nativeClientProxy = ClientProxyMock(.init(userID: "@alice:matrix.org"))
        nativeClientProxy.makeNativeCallBackendReturnValue = ElementCallFakeMatrixBackend()
        let service = ElementCallService(clientProxy: nativeClientProxy,
                                         mediaProvider: MediaProviderMock(.init()),
                                         userSettings: appSettings.userSettings(for: nativeClientProxy.userID))
        callFlowCoordinator.setNativeCallService(service)
        let controller = try #require(service.nativeCallController)
        navigationRootCoordinator.setOverlayCoordinator(NativeCallScreenCoordinator(parameters: .init(controller: controller)))
        
        // When the slot is cleared, then the screen goes with the stack, without waiting for the service's dismiss.
        callFlowCoordinator.setNativeCallService(nil)
        
        #expect(navigationRootCoordinator.overlayCoordinator == nil)
        #expect(service.nativeCallController == nil)
    }
    
    // MARK: - Helpers
    
    private func room(_ id: String) -> JoinedRoomProxyMock {
        JoinedRoomProxyMock(.init(id: id))
    }
}

private func makeAliceClientProxy() -> ClientProxyMock {
    ClientProxyMock(.init(userID: "@alice:matrix.org",
                          deviceID: "alice-device",
                          roomSummaryProvider: RoomSummaryProviderMock(.init(state: .loaded(.mockRooms)))))
}

private func makeAliceSession(clientProxy: ClientProxyMock = makeAliceClientProxy(), elementCallService: ElementCallServiceProtocol) -> UserSessionMock {
    UserSessionMock(.init(clientProxy: clientProxy, elementCallService: elementCallService))
}
