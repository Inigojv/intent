import SwiftUI

struct HomeProfilesListView: View {
  let profiles: [BlockedProfiles]
  let isBlocking: Bool
  let hasActiveOnDemandSession: Bool
  let activeProfileIds: Set<UUID>
  let activeUsageSessionIdByProfileId: [UUID: String]
  let elapsedTime: TimeInterval
  let pausedProfileIds: Set<UUID>
  let stopCountdownRemainingByProfileId: [UUID: Int]
  var isHardModeActionLocked: Bool = false
  let onManageTapped: () -> Void
  let onStartTapped: (BlockedProfiles) -> Void
  let onStopTapped: (BlockedProfiles) -> Void
  let onEditTapped: (BlockedProfiles) -> Void
  let onStatsTapped: (BlockedProfiles) -> Void
  let onGrantExtraTimeTapped: (BlockedProfiles, String?) -> Void
  var selectedProfileId: UUID? = nil
  var onSelectProfile: ((BlockedProfiles) -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionTitle(
        "Profiles",
        buttonText: "Manage",
        buttonAction: onManageTapped,
        buttonIcon: "brain.head.profile"
      )

      VStack(spacing: 0) {
        ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
          HomeProfileRow(
            profile: profile,
            isBlocking: isBlocking,
            hasActiveOnDemandSession: hasActiveOnDemandSession,
            activeUsageSessionId: activeUsageSessionIdByProfileId[profile.id],
            isActive: activeProfileIds.contains(profile.id),
            elapsedTime: elapsedTime,
            isPauseActive: pausedProfileIds.contains(profile.id),
            stopCountdownRemaining: stopCountdownRemainingByProfileId[profile.id],
            isHardModeActionLocked: isHardModeActionLocked,
            isSelected: profile.id == selectedProfileId,
            selectsInsights: onSelectProfile != nil,
            onSelected: {
              onSelectProfile?(profile)
            },
            onStartTapped: {
              onStartTapped(profile)
            },
            onStopTapped: {
              onStopTapped(profile)
            },
            onEditTapped: {
              onEditTapped(profile)
            },
            onStatsTapped: {
              onStatsTapped(profile)
            },
            onGrantExtraTimeTapped: {
              onGrantExtraTimeTapped(profile, activeUsageSessionIdByProfileId[profile.id])
            }
          )

          if index < profiles.count - 1 {
            Divider()
              .padding(.leading, 64)
          }
        }
      }
      .background(
        Color(.systemBackground),
        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
      )
    }
  }
}

struct HomeProfilesByStrategyListView: View {
  let profiles: [BlockedProfiles]
  let isBlocking: Bool
  let hasActiveOnDemandSession: Bool
  let activeProfileIds: Set<UUID>
  let enabledUsageProfileIds: Set<UUID>
  let activeUsageSessionIdByProfileId: [UUID: String]
  let elapsedTime: TimeInterval
  let pausedProfileIds: Set<UUID>
  let stopCountdownRemainingByProfileId: [UUID: Int]
  let isHardModeActionLocked: Bool
  let onManageUsageBasedTapped: () -> Void
  let onManageOnDemandTapped: () -> Void
  let onStartAllUsageTapped: () -> Void
  let onStartTapped: (BlockedProfiles) -> Void
  let onStopTapped: (BlockedProfiles) -> Void
  let onEditTapped: (BlockedProfiles) -> Void
  let onStatsTapped: (BlockedProfiles) -> Void
  let onGrantExtraTimeTapped: (BlockedProfiles, String?) -> Void

  private var usageBasedProfiles: [BlockedProfiles] {
    profiles.filter { $0.blockingStrategyId == UsageBasedBlockingStrategy.id }
  }

  private var onDemandProfiles: [BlockedProfiles] {
    profiles.filter { $0.blockingStrategyId != UsageBasedBlockingStrategy.id }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HomeProfilesStrategySection(
        title: "Allowances",
        profiles: usageBasedProfiles,
        isBlocking: isBlocking,
        hasActiveOnDemandSession: hasActiveOnDemandSession,
        activeProfileIds: activeProfileIds,
        enabledUsageProfileIds: enabledUsageProfileIds,
        activeUsageSessionIdByProfileId: activeUsageSessionIdByProfileId,
        elapsedTime: elapsedTime,
        pausedProfileIds: pausedProfileIds,
        stopCountdownRemainingByProfileId: stopCountdownRemainingByProfileId,
        isHardModeActionLocked: isHardModeActionLocked,
        onManageTapped: onManageUsageBasedTapped,
        onStartAllUsageTapped: onStartAllUsageTapped,
        onStartTapped: onStartTapped,
        onStopTapped: onStopTapped,
        onEditTapped: onEditTapped,
        onStatsTapped: onStatsTapped,
        onGrantExtraTimeTapped: onGrantExtraTimeTapped
      )

      if !onDemandProfiles.isEmpty {
        HomeProfilesStrategySection(
          title: "On-demand",
          profiles: onDemandProfiles,
          isBlocking: isBlocking,
          hasActiveOnDemandSession: hasActiveOnDemandSession,
          activeProfileIds: activeProfileIds,
          enabledUsageProfileIds: enabledUsageProfileIds,
          activeUsageSessionIdByProfileId: activeUsageSessionIdByProfileId,
          elapsedTime: elapsedTime,
          pausedProfileIds: pausedProfileIds,
          stopCountdownRemainingByProfileId: stopCountdownRemainingByProfileId,
          isHardModeActionLocked: isHardModeActionLocked,
          onManageTapped: onManageOnDemandTapped,
          onStartAllUsageTapped: {},
          onStartTapped: onStartTapped,
          onStopTapped: onStopTapped,
          onEditTapped: onEditTapped,
          onStatsTapped: onStatsTapped,
          onGrantExtraTimeTapped: onGrantExtraTimeTapped
        )
      }
    }
  }
}

private struct HomeProfilesStrategySection: View {
  let title: String
  let profiles: [BlockedProfiles]
  let isBlocking: Bool
  let hasActiveOnDemandSession: Bool
  let activeProfileIds: Set<UUID>
  let enabledUsageProfileIds: Set<UUID>
  let activeUsageSessionIdByProfileId: [UUID: String]
  let elapsedTime: TimeInterval
  let pausedProfileIds: Set<UUID>
  let stopCountdownRemainingByProfileId: [UUID: Int]
  let isHardModeActionLocked: Bool
  let onManageTapped: () -> Void
  let onStartAllUsageTapped: () -> Void
  let onStartTapped: (BlockedProfiles) -> Void
  let onStopTapped: (BlockedProfiles) -> Void
  let onEditTapped: (BlockedProfiles) -> Void
  let onStatsTapped: (BlockedProfiles) -> Void
  let onGrantExtraTimeTapped: (BlockedProfiles, String?) -> Void

  private var isUsageBasedSection: Bool {
    title == "Usage based"
  }

  private var hasEnabledUsageProfilesInSection: Bool {
    guard isUsageBasedSection else { return false }
    return profiles.contains { enabledUsageProfileIds.contains($0.id) }
  }

  private var hasStopCountdownInSection: Bool {
    profiles.contains { (stopCountdownRemainingByProfileId[$0.id] ?? 0) > 0 }
  }

  private var hasReadyStopConfirmationInSection: Bool {
    profiles.contains { stopCountdownRemainingByProfileId[$0.id] == 0 }
  }

  private var usageHeaderTitle: String {
    if hasStopCountdownInSection {
      return "Wait"
    }
    if hasReadyStopConfirmationInSection {
      return "Stop"
    }
    if hasEnabledUsageProfilesInSection {
      return "Stop all"
    }
    return "Start"
  }

  private var usageHeaderIcon: String {
    if hasStopCountdownInSection {
      return "timer"
    }
    if hasReadyStopConfirmationInSection {
      return "stop.fill"
    }
    return hasEnabledUsageProfilesInSection ? "stop.fill" : "play.fill"
  }

  private var usageHeaderColor: Color {
    if hasStopCountdownInSection {
      return .orange
    }
    if hasReadyStopConfirmationInSection {
      return .red
    }
    return hasEnabledUsageProfilesInSection ? .red : .green
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header

      VStack(spacing: 0) {
        ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
          HomeProfileRow(
            profile: profile,
            isBlocking: isBlocking,
            hasActiveOnDemandSession: hasActiveOnDemandSession,
            activeUsageSessionId: activeUsageSessionIdByProfileId[profile.id],
            isActive: activeProfileIds.contains(profile.id),
            elapsedTime: elapsedTime,
            isPauseActive: pausedProfileIds.contains(profile.id),
            stopCountdownRemaining: stopCountdownRemainingByProfileId[profile.id],
            isHardModeActionLocked: isHardModeActionLocked,
            isSelected: false,
            selectsInsights: false,
            onSelected: {},
            onStartTapped: { onStartTapped(profile) },
            onStopTapped: { onStopTapped(profile) },
            onEditTapped: { onEditTapped(profile) },
            onStatsTapped: { onStatsTapped(profile) },
            onGrantExtraTimeTapped: {
              onGrantExtraTimeTapped(profile, activeUsageSessionIdByProfileId[profile.id])
            }
          )

          if index < profiles.count - 1 {
            Divider()
              .padding(.leading, 64)
          }
        }
      }
      .background(
        Color(.systemBackground),
        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
      )
    }
  }

  private var header: some View {
    HStack {
      Text(title)
        .font(.headline)
        .fontWeight(.medium)
        .foregroundColor(.secondary)

      Spacer()

      if isUsageBasedSection {
        RoundedButton(
          usageHeaderTitle,
          action: onStartAllUsageTapped,
          textColor: usageHeaderColor,
          iconName: usageHeaderIcon
        )
      }

      RoundedButton(
        "Manage",
        action: onManageTapped,
        iconName: "brain.head.profile"
      )
    }
    .padding(.bottom, 10)
  }
}

private struct HomeProfileRow: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.modelContext) private var context
  @EnvironmentObject private var strategyManager: StrategyManager
  @EnvironmentObject private var themeManager: ThemeManager
  @State private var hasRoomForMiniChart = false

  let profile: BlockedProfiles
  let isBlocking: Bool
  let hasActiveOnDemandSession: Bool
  let activeUsageSessionId: String?
  let isActive: Bool
  let elapsedTime: TimeInterval
  let isPauseActive: Bool
  let stopCountdownRemaining: Int?
  let isHardModeActionLocked: Bool
  let isSelected: Bool
  let selectsInsights: Bool
  let onSelected: () -> Void
  let onStartTapped: () -> Void
  let onStopTapped: () -> Void
  let onEditTapped: () -> Void
  let onStatsTapped: () -> Void
  let onGrantExtraTimeTapped: () -> Void

  private var showsMiniChart: Bool {
    hasRoomForMiniChart && !dynamicTypeSize.isAccessibilitySize
  }

  private var canStart: Bool {
    if profile.blockingStrategyId == UsageBasedBlockingStrategy.id {
      return true
    }

    return !hasActiveOnDemandSession
  }

  private var canStop: Bool {
    profile.showStopButton(elapsedTime: elapsedTime) && !isHardModeActionLocked
  }

  private var blockingStrategy: BlockingStrategy? {
    guard let strategyId = profile.blockingStrategyId else { return nil }
    return StrategyManager.getStrategyFromId(id: strategyId)
  }

  private var activeAction: BlockingStrategySessionAction {
    blockingStrategy?.activeSessionAction(
      isPauseActive: isPauseActive,
      isEnabled: canStop
    ) ?? .stop(isEnabled: canStop)
  }

  private var strategyState: UsageBasedMonitoringState? {
    guard let activeUsageSessionId else { return nil }
    return UsageBasedActivityScheduler.state(
      for: profile.id,
      sessionId: activeUsageSessionId,
      at: Date(),
      calendar: .current
    )
  }

  private var usageConfiguration: UsageBasedStrategyData {
    UsageBasedStrategyData.decode(profile.strategyData)
  }

  private var usageBaseAllowanceMinutes: Int {
    max(1, strategyState?.baseAllowanceInMinutes ?? usageConfiguration.allowanceInMinutes)
  }

  private var usageGrantedExtraMinutes: Int {
    guard let state = strategyState else { return 0 }
    return max(0, state.allowanceInMinutes - usageBaseAllowanceMinutes)
  }

  private var usageDisplayTotalMinutes: Int {
    usageBaseAllowanceMinutes + usageGrantedExtraMinutes
  }

  private var usageUsedMinutes: Int {
    guard isActive else { return 0 }
    return strategyState?.usedMinutes ?? 0
  }

  private var usagePeriodUsedMinutes: Int {
    let used = max(0, usageUsedMinutes)
    if strategyState?.allowanceReached == true {
      return max(used, usageDisplayTotalMinutes)
    }
    return used
  }

  private var usageCappedUsedMinutes: Int {
    min(usageUsedMinutes, usageDisplayTotalMinutes)
  }

  private var usageRemainingMinutes: Int {
    max(0, usageDisplayTotalMinutes - usageUsedMinutes)
  }

  private var usageAllowanceIndicatorText: String {
    if usageGrantedExtraMinutes > 0 {
      return "\(usagePeriodUsedMinutes)m/\(usageBaseAllowanceMinutes)m + \(usageGrantedExtraMinutes)m"
    }

    return "\(usagePeriodUsedMinutes)m/\(usageBaseAllowanceMinutes)m"
  }

  private enum UsageVisualState {
    case inactive
    case paused
    case blocking
    case extraTime
    case active
  }

  private var usageVisualState: UsageVisualState {
    guard isActive else { return .inactive }
    if isPauseActive { return .paused }
    if strategyState?.allowanceReached == true { return .blocking }
    if usageGrantedExtraMinutes > 0 {
      return .extraTime
    }
    return .active
  }

  private var isStopCountdownVisible: Bool {
    guard isActive else { return false }
    guard let remaining = stopCountdownRemaining else { return false }
    return remaining > 0
  }

  private var usageStatusText: String? {
    if isStopCountdownVisible, let remaining = stopCountdownRemaining {
      return "Disabling in \(remaining)s"
    }

    if profile.schedule?.isActive == true {
      return "Scheduled"
    }

    guard strategyState != nil else { return nil }
    let interval = usageResetInterval
    guard interval > 0 else { return nil }
    return "Resets in \(max(1, Int(interval / 60)))m"
  }

  private var usageResetInterval: TimeInterval {
    if let currentHour = Calendar.current.dateInterval(of: .hour, for: Date()) {
      return max(0, currentHour.end.timeIntervalSinceNow)
    }

    guard let state = strategyState else { return 0 }
    let resetDate = state.windowStart.addingTimeInterval(3600)
    return max(0, resetDate.timeIntervalSinceNow)
  }

  private var nextResetInterval: TimeInterval {
    usageResetInterval
  }

  private var usageBarColor: Color {
    switch usageVisualState {
    case .inactive:
      return .gray
    case .paused:
      return .blue
    case .blocking:
      return .red
    case .extraTime:
      return .yellow
    case .active:
      return strategyState == nil ? .gray : .green
    }
  }

  private var usageStateLabelText: String {
    switch usageVisualState {
    case .inactive:
      return "Inactive"
    case .paused:
      return "Paused"
    case .blocking:
      return "Blocking"
    case .extraTime:
      return "Extra Time"
    case .active:
      return "Active"
    }
  }

  private var shouldShowUsageExtraTimeButton: Bool {
    profile.blockingStrategyId == UsageBasedBlockingStrategy.id
      && isActive
      && usageConfiguration.extraTimeInMinutes > 0
      && strategyState?.allowanceReached == true
  }

  private var usageBarProgress: CGFloat {
    if strategyState?.allowanceReached == true {
      return 1
    }

    return CGFloat(Double(usageCappedUsedMinutes) / Double(max(1, usageDisplayTotalMinutes)))
  }

  private var scheduleInfoText: String {
    guard let schedule = profile.schedule, schedule.isActive else {
      return "No schedule"
    }

    let dayLabel = formattedDaySummary(for: schedule.days)
    let startLabel = formattedScheduleTime(hour: schedule.startHour, minute: schedule.startMinute)
    let endLabel = formattedScheduleTime(hour: schedule.endHour, minute: schedule.endMinute)
    return "\(dayLabel) · \(startLabel)–\(endLabel)"
  }

  private func formattedDaySummary(for days: [Weekday]) -> String {
    let sorted = days.sorted { $0.rawValue < $1.rawValue }
    guard !sorted.isEmpty else { return "No schedule" }

    if sorted.count == 7 {
      return "Every day"
    }

    let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    if Set(sorted) == weekdays {
      return "Mon – Fri"
    }

    let weekends: Set<Weekday> = [.saturday, .sunday]
    if Set(sorted) == weekends {
      return "Sat – Sun"
    }

    if isConsecutiveRange(sorted) {
      let first = sorted.first!
      let last = sorted.last!
      return "\(shortWeekdayName(first)) – \(shortWeekdayName(last))"
    }

    return sorted.map(shortWeekdayName).joined(separator: ", ")
  }

  private func isConsecutiveRange(_ days: [Weekday]) -> Bool {
    guard days.count > 1 else { return false }
    let values = days.map { $0.rawValue }
    for index in 1..<values.count {
      if values[index] - values[index - 1] != 1 {
        return false
      }
    }
    return true
  }

  private func shortWeekdayName(_ weekday: Weekday) -> String {
    switch weekday {
    case .monday: return "Mon"
    case .tuesday: return "Tue"
    case .wednesday: return "Wed"
    case .thursday: return "Thu"
    case .friday: return "Fri"
    case .saturday: return "Sat"
    case .sunday: return "Sun"
    }
  }

  private func formattedScheduleTime(hour: Int, minute: Int) -> String {
    String(format: "%02d:%02d", hour, minute)
  }

  var body: some View {
    HStack(spacing: 12) {
      Button(action: selectsInsights ? onSelected : onEditTapped) {
        if profile.blockingStrategyId == UsageBasedBlockingStrategy.id {
          usageBasedSummary
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        } else {
          ProfileSummaryContent(
            profile: profile,
            isActive: false,
            metadata: .appsAndDomains,
            showsStatusLine: true,
            layout: .dashboard,
            statusMode: .scheduleOnly
          )
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel(
        selectsInsights ? "Show \(profile.name) insights" : "Edit \(profile.name)"
      )
      .accessibilityAddTraits(isSelected ? [.isSelected] : [])

      if showsMiniChart, profile.blockingStrategyId != UsageBasedBlockingStrategy.id {
        Button(action: onStatsTapped) {
          ProfileUsageMiniBarChart(profile: profile)
            .frame(width: 118, height: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show \(profile.name) insights")
      }

      actionMenu
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .background(
      isSelected ? themeManager.themeColor.opacity(0.4) : Color.clear,
      in: RoundedRectangle(cornerRadius: 16, style: .continuous)
    )
    .onGeometryChange(for: Bool.self) { geometry in
      // Reserve room for profile details, the chart, the action menu, and padding.
      geometry.size.width > 343
    } action: { hasRoom in
      hasRoomForMiniChart = hasRoom
    }
  }

  private var usageBasedSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(profile.name)
        .font(.headline)
        .fontWeight(.semibold)
        .lineLimit(1)

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          HStack(spacing: 6) {
            Image(systemName: "hourglass")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(usageBarColor)

            Text(usageAllowanceIndicatorText)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Spacer()

          if let statusText = usageStatusText {
            HStack(spacing: 5) {
              if isStopCountdownVisible {
                Image(systemName: "timer")
                  .font(.system(size: 11, weight: .semibold))
                  .foregroundStyle(.orange)
              }

              Text(statusText)
                .font(.caption)
                .foregroundStyle(isStopCountdownVisible ? .orange : .secondary)
            }
          }
        }

        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            Capsule()
              .fill(Color.secondary.opacity(0.15))
              .frame(height: 8)

            Capsule()
              .fill(usageBarColor)
              .frame(
                width: max(0, min(geometry.size.width, geometry.size.width * usageBarProgress)),
                height: 8
              )
          }
        }
        .frame(height: 8)

        Divider()
          .padding(.vertical, 2)

        HStack(alignment: .center, spacing: 8) {
          Image(systemName: "calendar.badge.clock")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)

          Text(scheduleInfoText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
        }
      }
    }
  }

  private var actionMenu: some View {
    Group {
      if profile.blockingStrategyId == UsageBasedBlockingStrategy.id {
        if shouldShowUsageExtraTimeButton {
          Button(action: onGrantExtraTimeTapped) {
            Image(systemName: "plus")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(.yellow)
              .frame(width: 32, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Grant extra time for \(profile.name)")
        }
      } else {
        Menu {
          Button(action: onStatsTapped) {
            Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
          }

          Button(action: onEditTapped) {
            Label("Edit", systemImage: "pencil")
          }

          if isActive {
            Button(action: onStopTapped) {
              Label(activeAction.title, systemImage: activeAction.systemImageName)
            }
            .disabled(!canStop)
          } else {
            Button(action: onStartTapped) {
              Label("Start", systemImage: "play.fill")
            }
            .disabled(!canStart)
          }
        } label: {
          Image(systemName: "ellipsis")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.gray)
            .frame(width: 32, height: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("More actions for \(profile.name)")
      }
    }
  }
}
