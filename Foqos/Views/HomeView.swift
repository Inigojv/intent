import SwiftData
import SwiftUI

struct HomeView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.scenePhase) private var scenePhase

  @EnvironmentObject private var requestAuthorizer: RequestAuthorizer
  @EnvironmentObject private var strategyManager: StrategyManager
  @EnvironmentObject private var alertsManager: AlertsManager
  @EnvironmentObject private var navigationManager: NavigationManager
  @EnvironmentObject private var ratingManager: RatingManager

  @ObservedObject private var quickActionManager = QuickActionManager.shared

  @Query(sort: [
    SortDescriptor(\BlockedProfiles.order, order: .forward),
    SortDescriptor(\BlockedProfiles.createdAt, order: .reverse),
  ]) private
    var profiles: [BlockedProfiles]

  @Query(
    filter: #Predicate<BlockedProfileSession> { $0.endTime != nil },
    sort: \BlockedProfileSession.endTime,
    order: .reverse
  ) private var recentCompletedSessions: [BlockedProfileSession]

  @Query(
    filter: #Predicate<BlockedProfileSession> { $0.endTime == nil },
    sort: \BlockedProfileSession.startTime,
    order: .reverse
  ) private var activeSessions: [BlockedProfileSession]

  @State private var presentation = HomePresentationState()
  @AppStorage("showIntroScreen") private var showIntroScreen = true

  private var isBlocking: Bool {
    strategyManager.isBlocking
  }

  private var quickActionProfiles: [QuickActionManager.ProfileSnapshot] {
    profiles.map { .init(id: $0.id, name: $0.name) }
  }

  private var isCountdownReloadDue: Bool {
    guard let activeSession = strategyManager.activeSession else {
      return false
    }

    return SessionTimeCalculator.isCountdownReloadDue(for: activeSession)
  }

  var body: some View {
    HomeDashboardView(
      profiles: profiles,
      sessions: recentCompletedSessions,
      alerts: alertsManager.alerts,
      onSupportTapped: { presentation.showDonationView = true },
      onSettingsTapped: { presentation.showSettingsView = true },
      onAlertTapped: presentAlert,
      onGuidedCreationTapped: { presentation.showGuidedProfileCreationView = true },
      onAdvancedCreationTapped: {
        presentation.profileCreationScope = .onDemand
        presentation.showNewProfileView = true
      },
      onInsightsTapped: { presentation.dashboardInsightsContext = $0 },
      onManageProfilesTapped: {
        presentation.profileListScope = .onDemand
        presentation.showOnDemandProfileList = true
      },
      onManageUsageBasedTapped: {
        presentation.profileListScope = .usageBased
        presentation.showUsageBasedProfileList = true
      },
      onManageOnDemandTapped: {
        presentation.profileListScope = .onDemand
        presentation.showOnDemandProfileList = true
      },
      onStartProfile: startProfile,
      onStopProfile: strategyButtonPress,
      onEditProfile: editProfile,
      onProfileInsightsTapped: { presentation.profileToShowStats = $0 },
      onLauncherTapped: { presentation.showStartProfilePicker = true },
      onActiveSessionTapped: { presentation.showActiveProfileSessionView = true }
    )
    .refreshable { loadApp() }
    .modifier(
      HomePresentations(
        presentation: $presentation,
        showIntroScreen: $showIntroScreen,
        profiles: profiles,
        onStartProfile: startProfile,
        onStopProfile: strategyButtonPress,
        alertDisabledReason: disabledReason,
        onAlertPrimaryAction: runAlertPrimaryAction,
        onDismissError: dismissAlert
      )
    )
    .onChange(of: navigationManager.profileId) { _, newValue in
      if let profileId = newValue, let url = navigationManager.link {
        toggleSessionFromDeeplink(profileId, link: url)
        navigationManager.clearNavigation()
      }
    }
    .onChange(of: navigationManager.navigateToProfileId) { _, newValue in
      if let profileId = newValue {
        presentation.navigateToProfileId = UUID(uuidString: profileId)
        presentation.showStartProfilePicker = true
        navigationManager.clearNavigation()
      }
    }
    .onChange(of: requestAuthorizer.isAuthorized) { _, newValue in
      if newValue {
        showIntroScreen = false
      }
      refreshAlerts()
    }
    .onChange(of: profiles) { oldValue, newValue in
      if !newValue.isEmpty {
        loadApp()
      }
      refreshAlerts()
    }
    .onChange(of: quickActionProfiles, initial: true) { _, newValue in
      quickActionManager.updateShortcutItems(for: newValue)
      startPendingQuickActionProfile()
    }
    .onChange(of: quickActionManager.pendingProfileId, initial: true) { _, _ in
      startPendingQuickActionProfile()
    }
    .onChange(of: scenePhase) { oldPhase, newPhase in
      if newPhase == .active {
        requestAuthorizer.refreshAuthorizationStatus()
        loadApp()
        refreshAlerts()
      } else if newPhase == .background {
        unloadApp()
      }
    }
    .onChange(of: isCountdownReloadDue, initial: true) { _, shouldReload in
      guard shouldReload else { return }
      strategyManager.loadActiveSession(context: context)
    }
    .onChange(of: isBlocking) { _, newValue in
      if !newValue {
        presentation.showActiveProfileSessionView = false
      }
    }
    .onReceive(strategyManager.$errorMessage) { errorMessage in
      guard let message = errorMessage, !presentation.showActiveProfileSessionView else { return }
      showErrorAlert(message: message)
    }
    .onAppear {
      onAppearApp()
    }
  }

  private func toggleSessionFromDeeplink(_ profileId: String, link: URL) {
    strategyManager
      .toggleSessionFromDeeplink(profileId, url: link, context: context)
  }

  private func strategyButtonPress(_ profile: BlockedProfiles) {
    strategyManager
      .toggleBlocking(context: context, activeProfile: profile)

    ratingManager.incrementLaunchCount()
  }

  private func startProfile(_ profile: BlockedProfiles) {
    let isUsageBasedProfile = profile.blockingStrategyId == UsageBasedBlockingStrategy.id
    let hasConflictingOnDemandSession = activeSessions.contains {
      $0.blockedProfile.blockingStrategyId != UsageBasedBlockingStrategy.id
        && $0.blockedProfile.id != profile.id
    }
    let isBlockedByOnDemandSession = !isUsageBasedProfile && hasConflictingOnDemandSession

    guard !isBlockedByOnDemandSession else {
      showErrorAlert(message: "Stop the active profile before starting another one.")
      return
    }

    strategyButtonPress(profile)
  }

  private func startPendingQuickActionProfile() {
    guard let profileId = quickActionManager.pendingProfileId else { return }
    // Profiles may not be loaded yet on a cold launch; the profiles onChange retries
    guard !profiles.isEmpty else { return }

    quickActionManager.pendingProfileId = nil

    guard let profile = profiles.first(where: { $0.id == profileId }) else {
      showErrorAlert(message: "That profile no longer exists.")
      return
    }

    // Quick actions can arrive before onAppear restores the active session.
    strategyManager.loadActiveSession(context: context)
    startProfile(profile)
  }

  private func editProfile(_ profile: BlockedProfiles) {
    if isUsageProfileEditLocked(profile) {
      showErrorAlert(message: "Disable this usage-based allowance before editing it.")
      return
    }

    presentation.profileToEdit = profile
  }

  private func isUsageProfileEditLocked(_ profile: BlockedProfiles) -> Bool {
    guard profile.blockingStrategyId == UsageBasedBlockingStrategy.id else {
      return false
    }

    return UsageBasedStrategyData.decode(profile.strategyData).isAllowanceEnabled
  }

  private func loadApp() {
    strategyManager.loadActiveSession(context: context)
  }

  private func onAppearApp() {
    requestAuthorizer.refreshAuthorizationStatus()
    strategyManager.loadActiveSession(context: context)
    strategyManager.cleanUpGhostSchedules(context: context)
    refreshAlerts()
  }

  private func refreshAlerts() {
    alertsManager.refreshAlerts(
      profiles: profiles,
      authorizationStatus: requestAuthorizer.getAuthorizationStatus()
    )
  }

  private func presentAlert(_ alert: HomeAlert) {
    alertsManager.present(alert)
  }

  private func disabledReason(for alert: HomeAlert) -> String? {
    return alertsManager.disabledReason(
      for: alert,
      profiles: profiles,
      isBlocking: isBlocking
    )
  }

  private func runAlertPrimaryAction(for alert: HomeAlert) {
    alertsManager.runPrimaryAction(
      for: alert,
      profiles: profiles,
      isBlocking: isBlocking,
      requestAuthorizer: requestAuthorizer,
      onScheduleRepaired: {
        loadApp()
        refreshAlerts()
      }
    )
  }

  private func unloadApp() {
    strategyManager.stopTimer()
  }

  private func showErrorAlert(message: String) {
    presentation.alertTitle = "Whoops"
    presentation.alertMessage = message
    presentation.showingAlert = true
  }

  private func dismissAlert() {
    presentation.showingAlert = false
    strategyManager.errorMessage = nil
  }
}

#Preview {
  HomeView()
    .environmentObject(RequestAuthorizer())
    .environmentObject(TipManager())
    .environmentObject(AlertsManager())
    .environmentObject(NavigationManager())
    .environmentObject(StrategyManager())
    .environmentObject(RatingManager())
    .environmentObject(ThemeManager())
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
    .onAppear {
      UserDefaults(suiteName: "preview")!.set(
        false,
        forKey: "showIntroScreen"
      )
    }
}
