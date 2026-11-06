import SwiftUI

struct HomeProfilesListView: View {
  let profiles: [BlockedProfiles]
  let isBlocking: Bool
  let hasActiveOnDemandSession: Bool
  let activeProfileIds: Set<UUID>
  let elapsedTime: TimeInterval
  let pausedProfileIds: Set<UUID>
  let stopCountdownProfileId: UUID?
  let stopCountdownRemaining: Int?
  var isHardModeActionLocked: Bool = false
  let onManageTapped: () -> Void
  let onStartTapped: (BlockedProfiles) -> Void
  let onStopTapped: (BlockedProfiles) -> Void
  let onEditTapped: (BlockedProfiles) -> Void
  let onStatsTapped: (BlockedProfiles) -> Void
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
            isActive: activeProfileIds.contains(profile.id),
            elapsedTime: elapsedTime,
            isPauseActive: pausedProfileIds.contains(profile.id),
            isStopCountdownActive: stopCountdownProfileId == profile.id,
            stopCountdownRemaining: stopCountdownRemaining,
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
  let elapsedTime: TimeInterval
  let pausedProfileIds: Set<UUID>
  let stopCountdownProfileId: UUID?
  let stopCountdownRemaining: Int?
  let isHardModeActionLocked: Bool
  let onManageUsageBasedTapped: () -> Void
  let onManageOnDemandTapped: () -> Void
  let onStartTapped: (BlockedProfiles) -> Void
  let onStopTapped: (BlockedProfiles) -> Void
  let onEditTapped: (BlockedProfiles) -> Void
  let onStatsTapped: (BlockedProfiles) -> Void

  private var usageBasedProfiles: [BlockedProfiles] {
    profiles.filter { $0.blockingStrategyId == UsageBasedBlockingStrategy.id }
  }

  private var onDemandProfiles: [BlockedProfiles] {
    profiles.filter { $0.blockingStrategyId != UsageBasedBlockingStrategy.id }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HomeProfilesStrategySection(
        title: "Usage based",
        profiles: usageBasedProfiles,
        isBlocking: isBlocking,
        hasActiveOnDemandSession: hasActiveOnDemandSession,
        activeProfileIds: activeProfileIds,
        elapsedTime: elapsedTime,
        pausedProfileIds: pausedProfileIds,
        stopCountdownProfileId: stopCountdownProfileId,
        stopCountdownRemaining: stopCountdownRemaining,
        isHardModeActionLocked: isHardModeActionLocked,
        onManageTapped: onManageUsageBasedTapped,
        onStartTapped: onStartTapped,
        onStopTapped: onStopTapped,
        onEditTapped: onEditTapped,
        onStatsTapped: onStatsTapped
      )

      if !onDemandProfiles.isEmpty {
        HomeProfilesStrategySection(
          title: "On-demand",
          profiles: onDemandProfiles,
          isBlocking: isBlocking,
          hasActiveOnDemandSession: hasActiveOnDemandSession,
          activeProfileIds: activeProfileIds,
          elapsedTime: elapsedTime,
          pausedProfileIds: pausedProfileIds,
          stopCountdownProfileId: stopCountdownProfileId,
          stopCountdownRemaining: stopCountdownRemaining,
          isHardModeActionLocked: isHardModeActionLocked,
          onManageTapped: onManageOnDemandTapped,
          onStartTapped: onStartTapped,
          onStopTapped: onStopTapped,
          onEditTapped: onEditTapped,
          onStatsTapped: onStatsTapped
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
  let elapsedTime: TimeInterval
  let pausedProfileIds: Set<UUID>
  let stopCountdownProfileId: UUID?
  let stopCountdownRemaining: Int?
  let isHardModeActionLocked: Bool
  let onManageTapped: () -> Void
  let onStartTapped: (BlockedProfiles) -> Void
  let onStopTapped: (BlockedProfiles) -> Void
  let onEditTapped: (BlockedProfiles) -> Void
  let onStatsTapped: (BlockedProfiles) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionTitle(
        title,
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
            isActive: activeProfileIds.contains(profile.id),
            elapsedTime: elapsedTime,
            isPauseActive: pausedProfileIds.contains(profile.id),
            isStopCountdownActive: stopCountdownProfileId == profile.id,
            stopCountdownRemaining: stopCountdownRemaining,
            isHardModeActionLocked: isHardModeActionLocked,
            isSelected: false,
            selectsInsights: false,
            onSelected: {},
            onStartTapped: { onStartTapped(profile) },
            onStopTapped: { onStopTapped(profile) },
            onEditTapped: { onEditTapped(profile) },
            onStatsTapped: { onStatsTapped(profile) }
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

private struct HomeProfileRow: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.modelContext) private var context
  @EnvironmentObject private var strategyManager: StrategyManager
  @EnvironmentObject private var themeManager: ThemeManager
  @State private var hasRoomForMiniChart = false

  let profile: BlockedProfiles
  let isBlocking: Bool
  let hasActiveOnDemandSession: Bool
  let isActive: Bool
  let elapsedTime: TimeInterval
  let isPauseActive: Bool
  let isStopCountdownActive: Bool
  let stopCountdownRemaining: Int?
  let isHardModeActionLocked: Bool
  let isSelected: Bool
  let selectsInsights: Bool
  let onSelected: () -> Void
  let onStartTapped: () -> Void
  let onStopTapped: () -> Void
  let onEditTapped: () -> Void
  let onStatsTapped: () -> Void

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
    UsageBasedActivityScheduler.state(for: profile.id)
  }

  private var usageConfiguration: UsageBasedStrategyData {
    UsageBasedStrategyData.decode(profile.strategyData)
  }

  private var usageTotalMinutes: Int {
    if !isActive {
      return max(1, usageConfiguration.allowanceInMinutes)
    }
    return max(1, strategyState?.allowanceInMinutes ?? usageConfiguration.allowanceInMinutes)
  }

  private var usageUsedMinutes: Int {
    guard isActive else { return 0 }
    return strategyState?.usedMinutes ?? 0
  }

  private var usageRemainingMinutes: Int {
    max(0, usageTotalMinutes - usageUsedMinutes)
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
    if let state = strategyState, state.allowanceInMinutes > usageConfiguration.allowanceInMinutes {
      return .extraTime
    }
    return .active
  }

  private var isStopCountdownVisible: Bool {
    guard isActive, isStopCountdownActive else { return false }
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

    guard let state = strategyState else { return nil }
    let resetDate = state.windowStart.addingTimeInterval(3600)
    let interval = max(0, resetDate.timeIntervalSinceNow)
    guard interval > 0 else { return nil }
    return "Resets in \(max(1, Int(interval / 60)))m"
  }

  private var nextResetInterval: TimeInterval {
    guard let state = strategyState else { return 0 }
    let resetDate = state.windowStart.addingTimeInterval(3600)
    return max(0, resetDate.timeIntervalSinceNow)
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

  private var usageBarProgress: CGFloat {
    CGFloat(
      UsageBasedActivityScheduler.usageProgress(
        for: strategyState,
        isActive: isActive,
        fallbackAllowanceInMinutes: usageConfiguration.allowanceInMinutes
      )
    )
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
            Circle()
              .fill(usageBarColor)
              .frame(width: 8, height: 8)

            Text(usageStateLabelText)
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

  private var actionButtonTitle: String {
    if !isActive {
      return "Start"
    }

    if isStopCountdownVisible, let remaining = stopCountdownRemaining {
      return "Stop (\(remaining)s)"
    }

    return activeAction.title
  }

  private func handleActionTap() {
    if !isActive {
      onStartTapped()
      return
    }

    if isStopCountdownVisible {
      strategyManager.confirmStopCountdown(context: context)
      return
    }

    onStopTapped()
  }

  private var actionButton: some View {
    Button(action: handleActionTap) {
      HStack(spacing: 6) {
        Image(systemName: isActive ? (isStopCountdownActive ? "stop.fill" : activeAction.systemImageName) : "play.fill")
          .font(.system(size: 12, weight: .semibold))

        Text(actionButtonTitle)
          .font(.subheadline)
          .fontWeight(.semibold)
      }
      .frame(minWidth: 72)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .buttonStyle(.borderedProminent)
    .tint(isStopCountdownVisible ? .orange : themeManager.themeColor)
    .disabled(isActive ? !canStop : !canStart)
    .accessibilityLabel(isActive ? "Stop or confirm stop for \(profile.name)" : "Start \(profile.name)")
  }

  private var actionMenu: some View {
    Group {
      if profile.blockingStrategyId == UsageBasedBlockingStrategy.id {
        actionButton
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
