import SwiftData
import SwiftUI

struct HomeDashboardView: View {
  @EnvironmentObject private var strategyManager: StrategyManager

  @Query(
    filter: #Predicate<BlockedProfileSession> { $0.endTime == nil },
    sort: \BlockedProfileSession.startTime,
    order: .reverse
  ) private var activeSessions: [BlockedProfileSession]

  let profiles: [BlockedProfiles]
  let sessions: [BlockedProfileSession]
  let alerts: [HomeAlert]
  let onSupportTapped: () -> Void
  let onSettingsTapped: () -> Void
  let onAlertTapped: (HomeAlert) -> Void
  let onGuidedCreationTapped: () -> Void
  let onAdvancedCreationTapped: () -> Void
  let onInsightsTapped: (DashboardInsightsContext) -> Void
  let onManageProfilesTapped: () -> Void
  let onManageUsageBasedTapped: () -> Void
  let onManageOnDemandTapped: () -> Void
  let onStartProfile: (BlockedProfiles) -> Void
  let onStopProfile: (BlockedProfiles) -> Void
  let onEditProfile: (BlockedProfiles) -> Void
  let onProfileInsightsTapped: (BlockedProfiles) -> Void
  let onLauncherTapped: () -> Void
  let onActiveSessionTapped: () -> Void

  @State private var selectedProfileId: UUID?
  // Profile selection updates the expanded detail; closing the screen keeps Home on top.
  @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar

  private var selectedProfile: BlockedProfiles? {
    profiles.first { $0.id == selectedProfileId } ?? profiles.first
  }

  private var bottomActiveProfile: BlockedProfiles? {
    guard let activeSessionProfile = strategyManager.activeSession?.blockedProfile else {
      return nil
    }

    return activeSessionProfile.blockingStrategyId == UsageBasedBlockingStrategy.id
      ? nil
      : activeSessionProfile
  }

  private var hasActiveOnDemandSession: Bool {
    activeSessions.contains { $0.blockedProfile.blockingStrategyId != UsageBasedBlockingStrategy.id }
  }

  private var activeProfileIds: Set<UUID> {
    Set(activeSessions.map { $0.blockedProfile.id })
  }

  private var pausedProfileIds: Set<UUID> {
    Set(activeSessions.filter { $0.isPauseActive }.map { $0.blockedProfile.id })
  }

  private var stopCountdownProfileId: UUID? {
    guard let countdownSessionId = strategyManager.stopCountdownSessionId else {
      return nil
    }

    return activeSessions.first(where: { $0.id == countdownSessionId })?.blockedProfile.id
  }

  var body: some View {
    HomeDashboardLayout(preferredCompactColumn: $preferredCompactColumn) { showsProfileInsights in
      dashboardContent(showsProfileInsights: showsProfileInsights)
    } insights: {
      profileInsights
        .toolbar(.visible, for: .navigationBar)
    }
  }

  private func dashboardContent(showsProfileInsights: Bool) -> some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 30) {
        HomeHeaderView(
          onSupportTapped: onSupportTapped,
          onSettingsTapped: onSettingsTapped,
          showsSupportTitle: !showsProfileInsights,
          titleFont: showsProfileInsights ? .title2 : .largeTitle
        )

        HomeAlertsView(alerts: alerts, onAlertTapped: onAlertTapped)
          .padding(.horizontal, 16)

        if profiles.isEmpty {
          Welcome(
            onGuidedTap: createGuidedProfile,
            onAdvancedTap: createAdvancedProfile
          )
          .padding(.horizontal, 16)
        } else if !showsProfileInsights {
          HomeProfilesByStrategyListView(
            profiles: profiles,
            isBlocking: strategyManager.isBlocking,
            hasActiveOnDemandSession: hasActiveOnDemandSession,
            activeProfileIds: activeProfileIds,
            elapsedTime: strategyManager.elapsedTime,
            pausedProfileIds: pausedProfileIds,
            stopCountdownProfileId: stopCountdownProfileId,
            stopCountdownRemaining: strategyManager.stopCountdownRemaining,
            isHardModeActionLocked:
              strategyManager.activeSession?.isSessionActionLockedByHardMode() ?? false,
            onManageUsageBasedTapped: onManageUsageBasedTapped,
            onManageOnDemandTapped: onManageOnDemandTapped,
            onStartTapped: onStartProfile,
            onStopTapped: onStopProfile,
            onEditTapped: onEditProfile,
            onStatsTapped: onProfileInsightsTapped
          )
          .padding(.horizontal, 16)
        } else {
          HomeProfilesListView(
            profiles: profiles,
            isBlocking: strategyManager.isBlocking,
            hasActiveOnDemandSession: hasActiveOnDemandSession,
            activeProfileIds: activeProfileIds,
            elapsedTime: strategyManager.elapsedTime,
            pausedProfileIds: pausedProfileIds,
            stopCountdownProfileId: stopCountdownProfileId,
            stopCountdownRemaining: strategyManager.stopCountdownRemaining,
            isHardModeActionLocked:
              strategyManager.activeSession?.isSessionActionLockedByHardMode() ?? false,
            onManageTapped: onManageProfilesTapped,
            onStartTapped: onStartProfile,
            onStopTapped: onStopProfile,
            onEditTapped: onEditProfile,
            onStatsTapped: selectProfile,
            selectedProfileId: selectedProfile?.id,
            onSelectProfile: selectProfile
          )
          .padding(.horizontal, 16)
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      if !profiles.isEmpty {
        HomeProfileLauncher(
          activeProfile: strategyManager.isBlocking ? bottomActiveProfile : nil,
          displayTime: strategyManager.sessionDisplayTime,
          isBreakActive: strategyManager.isBreakActive,
          isPauseActive: strategyManager.isPauseActive,
          onStartTapped: onLauncherTapped,
          onActiveTapped: onActiveSessionTapped
        )
      }
    }
    .padding(.top, 1)
    .navigationTitle("Home")
    .toolbar(.hidden, for: .navigationBar)
  }

  private var profileInsights: some View {
    Group {
      if let selectedProfile {
        ProfileInsightsContent(profile: selectedProfile)
          .id(selectedProfile.id)
      } else {
        ContentUnavailableView(
          "No Profiles",
          systemImage: "chart.line.uptrend.xyaxis",
          description: Text("Create a profile to see its focus insights here.")
        )
      }
    }
  }

  private func selectProfile(_ profile: BlockedProfiles) {
    selectedProfileId = profile.id
  }

  private func createGuidedProfile() {
    guard !strategyManager.isBlocking else { return }
    onGuidedCreationTapped()
  }

  private func createAdvancedProfile() {
    guard !strategyManager.isBlocking else { return }
    onAdvancedCreationTapped()
  }
}

private struct HomeDashboardPreview: View {
  let hasProfiles: Bool
  private let container: ModelContainer
  private let profile: BlockedProfiles
  private let session: BlockedProfileSession

  init(hasProfiles: Bool) {
    self.hasProfiles = hasProfiles
    do {
      container = try ModelContainer(
        for: BlockedProfiles.self, BlockedProfileSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
      )
      profile = BlockedProfiles(
        name: "Deep Work",
        blockingStrategyId: ManualBlockingStrategy.id,
        domains: ["example.com"]
      )
      session = BlockedProfileSession(tag: ManualBlockingStrategy.id, blockedProfile: profile)
      session.startTime = Date().addingTimeInterval(-3600)
      session.endTime = Date()
      container.mainContext.insert(profile)
      container.mainContext.insert(session)
      try container.mainContext.save()
    } catch {
      fatalError("Failed to create dashboard preview: \(error)")
    }
  }

  var body: some View {
    HomeDashboardView(
      profiles: hasProfiles ? [profile] : [],
      sessions: hasProfiles ? [session] : [],
      alerts: [],
      onSupportTapped: {},
      onSettingsTapped: {},
      onAlertTapped: { _ in },
      onGuidedCreationTapped: {},
      onAdvancedCreationTapped: {},
      onInsightsTapped: { _ in },
      onManageProfilesTapped: {},
      onManageUsageBasedTapped: {},
      onManageOnDemandTapped: {},
      onStartProfile: { _ in },
      onStopProfile: { _ in },
      onEditProfile: { _ in },
      onProfileInsightsTapped: { _ in },
      onLauncherTapped: {},
      onActiveSessionTapped: {}
    )
    .modelContainer(container)
    .environmentObject(StrategyManager())
    .environmentObject(ThemeManager())
    .defaultAppStorage(UserDefaults(suiteName: "home-dashboard-preview")!)
  }
}

#Preview("Dashboard") {
  HomeDashboardPreview(hasProfiles: true)
}

#Preview("Empty Dashboard") {
  HomeDashboardPreview(hasProfiles: false)
}
