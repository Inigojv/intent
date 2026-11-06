import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct DebugView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @EnvironmentObject var strategyManager: StrategyManager

  @Query(sort: \BlockedProfiles.order) private var allProfiles: [BlockedProfiles]
  @Query(
    filter: #Predicate<BlockedProfileSession> { $0.endTime == nil },
    sort: \BlockedProfileSession.startTime,
    order: .reverse
  ) private var activeSessions: [BlockedProfileSession]

  @State private var activeProfile: BlockedProfiles?
  @State private var showCopyConfirmation = false

  private var deviceActivities: [DeviceActivityName] {
    DeviceActivityCenterUtil.getDeviceActivities()
  }

  private var activeUsageSessions: [BlockedProfileSession] {
    activeSessions.filter { $0.blockedProfile.blockingStrategyId == UsageBasedBlockingStrategy.id }
  }

  private var usageMonitoringStates: [UsageBasedMonitoringState] {
    UsageBasedActivityScheduler.allStates
  }

  private var reachedUsageStates: [UsageBasedMonitoringState] {
    usageMonitoringStates.filter { $0.allowanceReached }
  }

  private var staleUsageStates: [UsageBasedMonitoringState] {
    let activeUsageSessionIDs = Set(activeUsageSessions.map(\.id))
    return usageMonitoringStates.filter { !activeUsageSessionIDs.contains($0.sessionId) }
  }

  private var usageCombinedReachedRestrictions: (
    applicationTokens: Set<ApplicationToken>,
    categoryTokens: Set<ActivityCategoryToken>,
    webDomainTokens: Set<WebDomainToken>
  ) {
    UsageBasedActivityScheduler.combinedReachedRestrictions(for: reachedUsageStates)
  }

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          // Strategy Manager Section (always shown)
          DebugSection(title: "Strategy Manager") {
            StrategyManagerDebugCard(strategyManager: strategyManager)
          }

          DebugSection(title: "Usage-Based Diagnostics") {
            usageBasedDiagnosticsCard
          }

          // Active Session Section (if available)
          if let session = strategyManager.activeSession {
            DebugSection(title: "Active Session") {
              SessionDebugCard(session: session)
            }
          }

          DebugSection(title: "Soft Unblock") {
            SoftUnblockDebugCard(diagnostics: makeSoftUnblockDiagnostics())
          }

          // Device Activities Section (always shown)
          DebugSection(title: "Device Activities (\(deviceActivities.count))") {
            DeviceActivitiesDebugCard(
              activities: deviceActivities,
              profileId: activeProfile?.id
            )
          }

          // All Profiles Section
          if !allProfiles.isEmpty {
            DebugSection(title: "All Profiles (\(allProfiles.count))") {
              VStack(alignment: .leading, spacing: 16) {
                ForEach(allProfiles) { profile in
                  VStack(alignment: .leading, spacing: 8) {
                    Text(profile.name)
                      .font(.headline)

                    ProfileDebugCard(profile: profile)

                    if let schedule = profile.schedule {
                      ScheduleDebugCard(schedule: schedule)
                    }

                    DebugSection(title: "Selected Activity") {
                      SelectedActivityDebugCard(selection: profile.selectedActivity)
                    }

                    if let domains = profile.domains, !domains.isEmpty {
                      DebugSection(title: "Domains (\(domains.count))") {
                        DomainsDebugCard(domains: domains)
                      }
                    }
                  }
                  .padding(.vertical, 8)

                  if profile.id != allProfiles.last?.id {
                    Divider()
                  }
                }
              }
            }
          }
        }
        .padding()
      }
      .navigationTitle("Debug Mode")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(action: { dismiss() }) {
            Image(systemName: "xmark")
          }
          .accessibilityLabel("Cancel")
        }

        ToolbarItem(placement: .topBarTrailing) {
          Button(action: { copyToMarkdown() }) {
            Image(systemName: "doc.on.doc")
          }
          .accessibilityLabel("Copy as Markdown")
        }
      }
      .onAppear {
        loadActiveProfile()
      }
      .refreshable {
        loadActiveProfile()
      }
      .alert("Copied to Clipboard", isPresented: $showCopyConfirmation) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Debug information has been copied as Markdown.")
      }
    }
  }

  private func loadActiveProfile() {
    if let session = strategyManager.activeSession {
      activeProfile = session.blockedProfile
    }
  }

  private func copyToMarkdown() {
    let softUnblockDiagnostics = makeSoftUnblockDiagnostics()
    var markdown = "# Debug Information\n\n"

    // Strategy Manager Section (always shown)
    markdown += "## Strategy Manager\n\n"
    markdown += "- **Has Active Session:** \(strategyManager.activeSession != nil ? "Yes" : "No")\n"
    markdown += "- **Elapsed Time:** \(Int(strategyManager.elapsedTime)) seconds\n"
    markdown += "- **Timer Active:** \(strategyManager.timer != nil ? "Yes" : "No")\n\n"

    markdown += "## Usage-Based Diagnostics\n\n"
    markdown += "- **Active Usage Sessions:** \(activeUsageSessions.count)\n"
    markdown += "- **Monitoring States:** \(usageMonitoringStates.count)\n"
    markdown += "- **Reached States:** \(reachedUsageStates.count)\n"
    markdown += "- **Stale States:** \(staleUsageStates.count)\n"
    markdown += "- **Stop Countdown Remaining:** \(strategyManager.stopCountdownRemaining.map(String.init) ?? "nil")\n"
    markdown += "- **Stop Countdown Session ID:** \(strategyManager.stopCountdownSessionId ?? "nil")\n"
    markdown += "- **Reached Union App Tokens:** \(usageCombinedReachedRestrictions.applicationTokens.count)\n"
    markdown += "- **Reached Union Category Tokens:** \(usageCombinedReachedRestrictions.categoryTokens.count)\n"
    markdown += "- **Reached Union Web Domains:** \(usageCombinedReachedRestrictions.webDomainTokens.count)\n\n"

    if !activeUsageSessions.isEmpty {
      markdown += "### Active Usage Sessions\n\n"
      for session in activeUsageSessions {
        markdown += "- **\(session.blockedProfile.name)**\n"
        markdown += "  - Session ID: \(session.id)\n"
        markdown += "  - Profile ID: \(session.blockedProfile.id.uuidString)\n"
        markdown += "  - Pause Active: \(session.isPauseActive ? "Yes" : "No")\n"
      }
      markdown += "\n"
    }

    if !usageMonitoringStates.isEmpty {
      markdown += "### Monitoring States\n\n"
      for state in usageMonitoringStates {
        markdown += "- **Session \(state.sessionId)**\n"
        markdown += "  - Profile ID: \(state.profileId.uuidString)\n"
        markdown += "  - Used/Allowance: \(state.usedMinutes)/\(state.allowanceInMinutes)\n"
        markdown += "  - Reached: \(state.allowanceReached ? "Yes" : "No")\n"
        markdown += "  - Window Start: \(DateFormatters.formatDate(state.windowStart))\n"
      }
      markdown += "\n"
    }

    // Active Session Section (if available)
    if let session = strategyManager.activeSession {
      markdown += "## Active Session\n\n"
      markdown += "- **Session ID:** \(session.id)\n"
      markdown += "- **Tag:** \(session.tag)\n"
      markdown += "- **Is Active:** \(session.isActive ? "Yes" : "No")\n"
      markdown += "- **Started At:** \(DateFormatters.formatDate(session.startTime))\n"

      if let endTime = session.endTime {
        markdown += "- **Ended At:** \(DateFormatters.formatDate(endTime))\n"
      }

      markdown += "- **Break Available:** \(session.isBreakAvailable ? "Yes" : "No")\n"
      markdown += "- **Break Active:** \(session.isBreakActive ? "Yes" : "No")\n"
      markdown +=
        "- **Used Break Duration:** \(DateFormatters.formatDuration(session.usedBreakDurationInSeconds))\n"
      markdown +=
        "- **Remaining Break Allowance:** \(DateFormatters.formatDuration(session.remainingBreakAllowance()))\n"

      if let breakStartTime = session.breakStartTime {
        markdown += "- **Break Started At:** \(DateFormatters.formatDate(breakStartTime))\n"
      }

      if let breakEndTime = session.breakEndTime {
        markdown += "- **Break Ended At:** \(DateFormatters.formatDate(breakEndTime))\n"
      }

      markdown += "- **Force Started:** \(session.forceStarted ? "Yes" : "No")\n"
      markdown += "- **Duration:** \(DateFormatters.formatDuration(session.duration))\n\n"
    }

    markdown += softUnblockDiagnostics.markdown()

    // Device Activities Section (always shown)
    markdown += "## Device Activities (\(deviceActivities.count))\n\n"
    if deviceActivities.isEmpty {
      markdown += "No device activities scheduled.\n\n"
    } else {
      for (index, activity) in deviceActivities.enumerated() {
        markdown += "### Activity \(index + 1)\n"
        markdown += "- **Name:** \(activity.rawValue)\n"
        markdown += "- **Type:** \(activityType(for: activity))\n"
        if let profileId = activeProfile?.id {
          markdown +=
            "- **Matches Active Profile:** \(isActivityForProfile(activity, profileId: profileId) ? "Yes" : "No")\n"
        }
        markdown += "\n"
      }
    }

    // All Profiles Section
    if !allProfiles.isEmpty {
      markdown += "## All Profiles (\(allProfiles.count))\n\n"

      for (index, profile) in allProfiles.enumerated() {
        markdown += "### Profile \(index + 1): \(profile.name)\n\n"
        markdown += "- **ID:** \(profile.id.uuidString)\n"
        markdown += "- **Created:** \(DateFormatters.formatDate(profile.createdAt))\n"
        markdown += "- **Updated:** \(DateFormatters.formatDate(profile.updatedAt))\n"
        markdown += "- **Order:** \(profile.order)\n"

        if let strategyId = profile.blockingStrategyId {
          markdown += "- **Blocking Strategy ID:** \(strategyId)\n"
        }

        markdown += "- **Allow Mode:** \(profile.enableAllowMode ? "Yes" : "No")\n"
        markdown += "- **Allow Mode Domains:** \(profile.enableAllowModeDomains ? "Yes" : "No")\n"
        markdown +=
          "- **Adult Content Blocking:** \(profile.enableAdultContentBlocking ? "Enabled" : "Disabled")\n"
        markdown += "- **Live Activity:** \(profile.enableLiveActivity ? "Enabled" : "Disabled")\n"
        markdown += "- **Breaks:** \(profile.enableBreaks ? "Enabled" : "Disabled")\n"
        markdown +=
          "- **Allow Multiple Breaks:** \(profile.allowMultipleBreaks ? "Enabled" : "Disabled")\n"
        markdown += "- **Strict Mode:** \(profile.enableStrictMode ? "Enabled" : "Disabled")\n"
        markdown +=
          "- **Prevent App Installation:** \(profile.enableBlockAppInstallation ? "Enabled" : "Disabled")\n"
        markdown +=
          "- **Disable Background Stops:** \(profile.disableBackgroundStops ? "Yes" : "No")\n"

        if let reminderTime = profile.reminderTimeInSeconds {
          markdown += "- **Reminder Time:** \(reminderTime / 60) minutes\n"
        }

        if let customMessage = profile.customReminderMessage, !customMessage.isEmpty {
          markdown += "- **Custom Reminder Message:** \(customMessage)\n"
        }

        if let physicalUnblockItems = profile.physicalUnblockItems, !physicalUnblockItems.isEmpty {
          markdown += "- **Physical Unlock Items:** \(physicalUnblockItems.count)\n"

          for item in physicalUnblockItems {
            markdown += "  - \(item.type.displayName): \(item.name)\n"
          }
        }

        markdown += "- **Total Sessions:** \(profile.sessions.count)\n"

        // Schedule Section
        if let schedule = profile.schedule {
          markdown += "\n**Schedule:**\n\n"

          if schedule.days.isEmpty {
            markdown += "- **Days:** All days\n"
          } else {
            let dayNames = schedule.days.sorted(by: { $0.rawValue < $1.rawValue }).map { $0.name }
              .joined(separator: ", ")
            markdown += "- **Days:** \(dayNames)\n"
          }

          markdown +=
            "- **Start Time:** \(String(format: "%02d:%02d", schedule.startHour, schedule.startMinute))\n"
          markdown +=
            "- **End Time:** \(String(format: "%02d:%02d", schedule.endHour, schedule.endMinute))\n"
          markdown += "- **Updated At:** \(DateFormatters.formatDate(schedule.updatedAt))\n"
        }

        // Selected Activity Section
        markdown += "\n**Selected Activity:**\n\n"
        markdown += "- **Applications:** \(profile.selectedActivity.applicationTokens.count)\n"
        markdown += "- **Categories:** \(profile.selectedActivity.categoryTokens.count)\n"
        markdown += "- **Web Domains:** \(profile.selectedActivity.webDomainTokens.count)\n"

        // Domains Section
        if let domains = profile.domains, !domains.isEmpty {
          markdown += "\n**Domains (\(domains.count)):**\n\n"
          for domain in domains {
            markdown += "- \(domain)\n"
          }
        }

        markdown += "\n"
      }
    }

    // Copy to clipboard
    UIPasteboard.general.string = markdown
    showCopyConfirmation = true
  }

  private func activityType(for activity: DeviceActivityName) -> String {
    let rawValue = activity.rawValue

    if rawValue.hasPrefix(SoftUnblockGrantScheduler.activityId) {
      return "Soft Unblock Grant Timer"
    } else if rawValue.hasPrefix(BreakTimerActivity.id) {
      return "Break Timer"
    } else if rawValue.hasPrefix(PauseTimerActivity.id) {
      return "Pause Timer"
    } else if rawValue.hasPrefix(StrategyTimerActivity.id) {
      return "Strategy Timer"
    } else if rawValue.hasPrefix(ScheduleTimerActivity.id) {
      return "Schedule Timer"
    } else {
      // Check if it's a UUID (legacy schedule format)
      if UUID(uuidString: rawValue) != nil {
        return "Schedule Timer (Legacy)"
      }
      return "Unknown"
    }
  }

  private func isActivityForProfile(_ activity: DeviceActivityName, profileId: UUID) -> Bool {
    let rawValue = activity.rawValue
    let profileIdString = profileId.uuidString

    if let identifiers = SoftUnblockGrantScheduler.identifiers(from: activity) {
      return identifiers.profileId == profileId
    }

    // Check if it's a break timer activity for this profile
    if rawValue.hasPrefix(BreakTimerActivity.id) {
      return rawValue.hasSuffix(profileIdString)
    }

    // Check if it's a pause timer activity for this profile
    if rawValue.hasPrefix(PauseTimerActivity.id) {
      return rawValue.hasSuffix(profileIdString)
    }

    // Check if it's a strategy timer activity for this profile
    if rawValue.hasPrefix(StrategyTimerActivity.id) {
      return rawValue.hasSuffix(profileIdString)
    }

    // Check if it's a schedule timer activity for this profile
    if rawValue.hasPrefix(ScheduleTimerActivity.id) {
      return rawValue.hasSuffix(profileIdString)
    }

    // Check if it's a legacy schedule format (just the UUID)
    return rawValue == profileIdString
  }

  private func makeSoftUnblockDiagnostics(
    capturedAt: Date = Date()
  ) -> SoftUnblockDiagnostics {
    let store = SoftUnblockGrantStore.debugSnapshot()
    let sharedSnapshots = SharedData.profileSnapshots
    let activeProfileId = store.activeSession?.profileId
    let modelProfilesById = Dictionary(uniqueKeysWithValues: allProfiles.map { ($0.id, $0) })
    let sharedProfilesById = Dictionary(
      uniqueKeysWithValues: sharedSnapshots.values.map { ($0.id, $0) }
    )
    let softUnblockStrategyIds: Set<String> = [
      NFCSoftUnblockBlockingStrategy.id,
      QRSoftUnblockBlockingStrategy.id,
    ]
    let modelSoftUnblockIds: [UUID] = allProfiles.compactMap { profile -> UUID? in
      guard let strategyId = profile.blockingStrategyId else { return nil }
      return softUnblockStrategyIds.contains(strategyId) ? profile.id : nil
    }
    let sharedSoftUnblockIds: [UUID] = sharedSnapshots.values.compactMap {
      profile -> UUID? in
      guard let strategyId = profile.blockingStrategyId else { return nil }
      return softUnblockStrategyIds.contains(strategyId) ? profile.id : nil
    }
    var profileIds = Set(modelSoftUnblockIds + sharedSoftUnblockIds)
    if let activeProfileId {
      profileIds.insert(activeProfileId)
    }

    let configurations: [SoftUnblockDiagnostics.ProfileConfiguration] = profileIds.compactMap {
      profileId -> SoftUnblockDiagnostics.ProfileConfiguration? in
      let modelProfile = modelProfilesById[profileId]
      let sharedProfile = sharedProfilesById[profileId]
      guard modelProfile != nil || sharedProfile != nil else { return nil }

      return SoftUnblockDiagnostics.ProfileConfiguration(
        id: profileId,
        name: modelProfile?.name ?? sharedProfile?.name ?? "Unknown Profile",
        modelStrategyId: modelProfile?.blockingStrategyId,
        modelStrategyData: modelProfile?.strategyData,
        sharedSnapshot: sharedProfile
      )
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    return SoftUnblockDiagnostics(
      capturedAt: capturedAt,
      store: store,
      sharedSession: SharedData.getActiveSharedSession(),
      profileConfigurations: configurations,
      activities: deviceActivities
    )
  }

  private var usageBasedDiagnosticsCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Group {
        DebugRow(label: "Active Usage Sessions", value: "\(activeUsageSessions.count)")
        DebugRow(label: "Monitoring States", value: "\(usageMonitoringStates.count)")
        DebugRow(label: "Reached States", value: "\(reachedUsageStates.count)")
        DebugRow(label: "Stale States", value: "\(staleUsageStates.count)")
      }

      Divider()

      Group {
        DebugRow(
          label: "Stop Countdown Remaining",
          value: strategyManager.stopCountdownRemaining.map(String.init) ?? "nil"
        )
        DebugRow(
          label: "Stop Countdown Session ID",
          value: strategyManager.stopCountdownSessionId ?? "nil"
        )
      }

      Divider()

      Group {
        DebugRow(
          label: "Reached Union App Tokens",
          value: "\(usageCombinedReachedRestrictions.applicationTokens.count)"
        )
        DebugRow(
          label: "Reached Union Category Tokens",
          value: "\(usageCombinedReachedRestrictions.categoryTokens.count)"
        )
        DebugRow(
          label: "Reached Union Web Domains",
          value: "\(usageCombinedReachedRestrictions.webDomainTokens.count)"
        )
      }

      if !activeUsageSessions.isEmpty {
        Divider()

        VStack(alignment: .leading, spacing: 4) {
          Text("Active Usage Sessions:")
            .font(.caption)
            .foregroundColor(.secondary)

          ForEach(activeUsageSessions, id: \.id) { session in
            Text("• \(session.blockedProfile.name) (\(session.id))")
              .font(.caption)
              .foregroundColor(.primary)
          }
        }
      }

      if !usageMonitoringStates.isEmpty {
        Divider()

        VStack(alignment: .leading, spacing: 4) {
          Text("Monitoring States:")
            .font(.caption)
            .foregroundColor(.secondary)

          ForEach(Array(usageMonitoringStates.enumerated()), id: \.offset) { _, state in
            Text(
              "• \(state.sessionId)  used \(state.usedMinutes)/\(state.allowanceInMinutes)  reached=\(state.allowanceReached)"
            )
            .font(.caption)
            .foregroundColor(.primary)
          }
        }
      }
    }
  }
}

#Preview {
  DebugView()
    .environmentObject(StrategyManager.shared)
    .modelContainer(for: [BlockedProfiles.self, BlockedProfileSession.self], inMemory: true)
}
